import {
  EVENT_FLAP,
  EVENT_RESPAWN,
  FlappyFlight,
  type FlappyFlightState,
} from "../flappy_flight/flight.js";
import type { CubioGesture } from "../three_view/cubio.js";
import { createFallbackView } from "./fallback.js";
import { clockText, FlappyRaceHud, ordinal, type FloatingHeart } from "./hud.js";
import {
  flightState,
  isEvent,
  isSnapshot,
  isState,
  type Message,
  type ResultEntry,
  type Snapshot,
} from "./messages.js";
import { FlappyPrediction } from "./prediction.js";
import { RaceClock } from "./race_clock.js";
import type { FlappyViewModule, Presentation, ViewSetup } from "./types.js";

export { isSnapshot, isEvent, isState };

/** How long GO stays on screen after the countdown, s. */
const GO_SECONDS = 0.6;
/** How quickly the camera moves to a respawn spot while the Cubio is out of play, s. */
const FOCUS_SECONDS = 0.25;
/** Turns per second of the dizzy tumble. */
const TUMBLE_TURNS = 1.5;

/** One race as the phone knows it, rebuilt from every snapshot. */
interface Race {
  snapshot: Snapshot;
  clock: RaceClock;
  prediction: FlappyPrediction;
  seq: number;
  place: number;
  ownResult?: ResultEntry;
  wasFlying: boolean;
  /** Local time of the last hit, and where the Cubio was when it happened. */
  hitAt: number;
  hitX: number;
  hitY: number;
  heartSpent: boolean;
  takenCount: number;
  pickupAt: number;
  tilt: number;
  focusX: number;
}

/** The face the phone's Cubio shows for one moment of the race. */
export function faceFor(
  moment: "countdown" | "flying" | "pickup" | "hit" | "waiting" | "finished" | "results",
  place = 0,
  players = 1,
): string {
  switch (moment) {
    case "countdown":
      return "face_scheming";
    case "pickup":
      return "face_beaming";
    case "hit":
      return "face_dizzy";
    case "waiting":
      return "face_worried";
    case "results":
      if (players === 1) return place === 1 ? "face_slightly_smiling" : "face_disappointed";
      return place >= 1 && place <= 3 ? "face_mischievous" : "face_disappointed";
    default:
      return "face_slightly_smiling";
  }
}

/** The text of the player's own result. */
export function resultText(result: ResultEntry | undefined): [string, string] {
  if (!result) return ["Race over", ""];
  if (result.dnf) return ["Did not finish", ""];

  const place = `${ordinal(result.place)} place`;
  if (!result.finished) return [place, `Reached ${Math.floor(result.distance)} m`];
  const seconds = result.finish_msec / 1000;
  const hundredths = String(Math.floor((result.finish_msec % 1000) / 10)).padStart(2, "0");
  return [place, `Time ${clockText(Math.floor(seconds))}.${hundredths}`];
}

/**
 * The Flappy Race phone: the player's own Cubio predicted from their taps, the course, the
 * hearts and the race's text, portrait. Every touch-down on the surface is one flap.
 */
export class FlappyRacePhone {
  private race?: Race;
  private presentation?: Presentation;
  private courseKey = "";
  private generation = 0;
  private request = 0;
  private previous = 0;
  private readonly hud: FlappyRaceHud;
  private readonly viewCanvas: HTMLCanvasElement;
  private readonly fallbackCanvas: HTMLCanvasElement;
  private readonly results: HTMLElement;

  constructor(
    private readonly surface: HTMLElement,
    private readonly send: (message: { type: "flappy_tap"; seq: number; tick: number }) => void,
    private readonly loadView: () => Promise<FlappyViewModule>,
  ) {
    this.hud = new FlappyRaceHud(surface);
    this.viewCanvas = surface.querySelector<HTMLCanvasElement>(".flappy-view")!;
    this.fallbackCanvas = surface.querySelector<HTMLCanvasElement>(".flappy-fallback")!;
    this.results = surface.querySelector<HTMLElement>(".flappy-results")!;
    surface.addEventListener("pointerdown", (event) => {
      if (event.pointerType === "mouse" && event.button !== 0) return;
      if (this.tap(performance.now())) event.preventDefault();
    });
  }

  show(): void {
    this.surface.hidden = false;
    if (!this.request) this.request = requestAnimationFrame(this.frame);
  }

  hide(): void {
    this.generation++;
    if (this.request) cancelAnimationFrame(this.request);
    this.request = 0;
    this.previous = 0;
    this.presentation?.dispose();
    this.presentation = undefined;
    this.courseKey = "";
    this.race = undefined;
    this.hud.clear();
    this.surface.hidden = true;
  }

  receive(message: Message): void {
    const now = performance.now();
    if (isSnapshot(message)) {
      this.start(message, now);
      return;
    }

    const race = this.race;
    if (!race) return;
    if (isState(message)) race.clock.observe(message.clock_tick, now);
    const own = message.own;
    if (own) {
      race.prediction.confirm(message.tick, this.settledFrom(race.snapshot, own.flight));
      race.place = own.place;
    }
    if (isEvent(message) && message.event === "finish" && message.place) race.place = message.place;
  }

  /** A touch-down: one flap at the next tick, sent to the host with that tick. */
  private tap(now: number): boolean {
    const race = this.race;
    if (!race || this.surface.hidden || race.snapshot.phase === "results") return false;
    if (race.clock.tick(now) < 0 || race.prediction.finished || !race.snapshot.own.connected)
      return false;

    const tick = race.prediction.tap();
    race.seq += 1;
    this.send({ type: "flappy_tap", seq: race.seq, tick });
    return true;
  }

  private start(snapshot: Snapshot, now: number): void {
    const flight = new FlappyFlight(snapshot.flight, snapshot.course.flight);
    const clock = new RaceClock();
    clock.observe(snapshot.clock_tick, now);
    const state = this.settledFrom(snapshot, snapshot.own.flight);
    const previous = this.race;
    this.race = {
      snapshot,
      clock,
      prediction: new FlappyPrediction(flight, state, snapshot.tick),
      seq: Math.max(snapshot.own.last_seq, previous?.seq ?? -1),
      place: snapshot.own.place,
      ownResult: snapshot.own_result,
      wasFlying: state.flying,
      hitAt: Number.NEGATIVE_INFINITY,
      hitX: state.x,
      hitY: state.y,
      heartSpent: false,
      takenCount: state.taken.reduce((sum, taken) => sum + taken, 0),
      pickupAt: Number.NEGATIVE_INFINITY,
      tilt: 0,
      focusX: state.x,
    };
    const results = snapshot.phase === "results";
    this.results.hidden = !results;
    if (results) {
      const [title, detail] = resultText(snapshot.own_result);
      this.results.querySelector(".flappy-result-place")!.textContent = title;
      this.results.querySelector(".flappy-result-detail")!.textContent = detail;
    }
    const flightCourse = snapshot.course.flight;
    const key = JSON.stringify([
      flightCourse.finish_x,
      flightCourse.obstacles,
      snapshot.character_color,
    ]);
    if (key !== this.courseKey) this.mount(key, snapshot);
    this.show();
  }

  private mount(key: string, snapshot: Snapshot): void {
    const generation = ++this.generation;
    this.courseKey = key;
    this.presentation?.dispose();
    const setup: ViewSetup = {
      course: snapshot.course,
      color: `#${snapshot.character_color.replace(/^#/, "")}`,
      focusShare: snapshot.view.phone_cubio_screen_share,
    };
    this.viewCanvas.hidden = true;
    this.fallbackCanvas.hidden = false;
    this.presentation = createFallbackView(this.fallbackCanvas, setup);
    void this.loadView()
      .then((module) => module.createFlappyRaceView(this.viewCanvas, setup))
      .then(
        (presentation) => {
          if (generation !== this.generation) {
            presentation.dispose();
            return;
          }
          this.presentation?.dispose();
          this.presentation = presentation;
          this.fallbackCanvas.hidden = true;
          this.viewCanvas.hidden = false;
        },
        () => {
          /* The fallback stays. */
        },
      );
  }

  private settledFrom(snapshot: Snapshot, flight: Snapshot["own"]["flight"]): FlappyFlightState {
    return flightState(flight, snapshot.flight, snapshot.course.flight.pickups.length);
  }

  private frame = (now: number): void => {
    this.request = requestAnimationFrame(this.frame);
    const race = this.race;
    const presentation = this.presentation;
    const delta = this.previous ? Math.min(0.1, (now - this.previous) / 1000) : 0;
    this.previous = now;
    if (!race || !presentation || document.hidden) return;

    const { snapshot, prediction } = race;
    const view = snapshot.view;
    const clockTick = race.clock.tick(now);
    const events = snapshot.phase !== "results" ? prediction.advanceTo(clockTick) : 0;
    prediction.blend(delta, view.correction_seconds);
    const state = prediction.state;

    let gesture: CubioGesture | undefined;
    if (events & EVENT_FLAP) gesture = "flap";
    if (events & EVENT_RESPAWN || (!race.wasFlying && state.flying)) gesture = "respawn";
    if (race.wasFlying && !state.flying) {
      gesture = "hit";
      race.hitAt = now;
      race.heartSpent = !state.hearts.owed;
      if (race.heartSpent) {
        const to = presentation.project(state.x, state.y);
        this.hud.flyHeart(state.hearts.full, to, view.heart_flight_seconds);
      }
    }
    if (state.flying) {
      race.hitX = prediction.drawnX;
      race.hitY = prediction.drawnY;
    }
    race.wasFlying = state.flying;
    const taken = state.taken.reduce((sum, value) => sum + value, 0);
    if (taken > race.takenCount) race.pickupAt = now;
    race.takenCount = taken;

    const sinceHit = (now - race.hitAt) / 1000;
    const tumbling = !state.flying && sinceHit < view.hit_tumble_seconds;
    const results = snapshot.phase === "results";
    let face = faceFor("flying");
    if (results) face = faceFor("results", snapshot.own_result?.place ?? 0, snapshot.player_count);
    else if (clockTick < 0) face = faceFor("countdown");
    else if (tumbling) face = faceFor("hit");
    else if (!state.flying) face = faceFor("waiting");
    else if ((now - race.pickupAt) / 1000 < view.pickup_face_seconds) face = faceFor("pickup");

    const tuning = snapshot.flight;
    const speed = state.verticalSpeed;
    const target =
      speed >= 0
        ? (Math.min(1, speed / tuning.flap_velocity) * view.tilt_up_degrees * Math.PI) / 180
        : (-Math.min(1, -speed / tuning.max_fall_speed) * view.tilt_down_degrees * Math.PI) / 180;
    const follow =
      view.tilt_response_seconds > 0 ? 1 - Math.exp(-delta / view.tilt_response_seconds) : 1;
    race.tilt += (target - race.tilt) * follow;
    const focusTarget = state.flying ? prediction.drawnX : tumbling ? race.hitX : state.x;
    race.focusX = state.flying
      ? focusTarget
      : race.focusX + (focusTarget - race.focusX) * (1 - Math.exp(-delta / FOCUS_SECONDS));

    presentation.draw({
      delta,
      focusX: race.focusX,
      cubioX: tumbling ? race.hitX : prediction.drawnX,
      cubioY: tumbling ? race.hitY : prediction.drawnY,
      tilt: tumbling ? -sinceHit * TUMBLE_TURNS * Math.PI * 2 : race.tilt,
      cubioVisible: state.flying || tumbling || state.ready,
      face,
      gesture,
      hitSeconds: view.hit_tumble_seconds,
      tumbling,
      idle: (!state.flying && !tumbling) || results || clockTick < 0,
      taken: state.taken,
    });

    const heartLanded = !race.heartSpent || sinceHit >= view.heart_flight_seconds;
    let floating: FloatingHeart | undefined;
    if (!state.flying && heartLanded && !results)
      floating = {
        at: presentation.project(state.x, state.y),
        state: state.hearts.owed ? "owed" : state.ready ? "ready" : "cooling",
        refillShare: state.hearts.refillShare(),
      };
    let cue = "";
    if (clockTick < 0) cue = String(Math.max(1, Math.ceil(race.clock.untilGo(now) / 1000)));
    else if (clockTick < GO_SECONDS * snapshot.tick_rate) cue = "GO!";
    if (prediction.finished && !results)
      cue = race.place > 0 ? `You finished ${ordinal(race.place)}!` : "Finished!";
    const ticksLeft = snapshot.race_ticks - Math.max(0, clockTick);
    this.hud.update({
      hearts: {
        count: tuning.heart_count,
        full: state.hearts.full,
        refillShare: state.hearts.refillShare(),
      },
      progress: prediction.drawnX / snapshot.course.flight.finish_x,
      secondsLeft: ticksLeft / snapshot.tick_rate,
      lastSeconds: clockTick >= snapshot.last_seconds_tick,
      cue: results ? "" : cue,
      floating,
    });

    const data = this.surface.dataset;
    data.phase = results ? "results" : clockTick < 0 ? "countdown" : "racing";
    data.tick = String(prediction.tick);
    data.flying = String(state.flying);
    data.ready = String(state.ready);
    data.rising = String(state.verticalSpeed > 0);
    data.corrections = String(prediction.corrections);
  };
}
