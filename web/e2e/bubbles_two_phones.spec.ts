import { expect, test } from "./fixtures";

const SWIPES: [number, number][] = [
  [120, 0],
  [0, 120],
  [-120, 0],
  [0, -120],
  [90, 90],
  [-90, -90],
];

test("two phones join, play a Bubbles round and return to the lobby", async ({
  host,
  openPhone,
}) => {
  const phones = [await openPhone("Ana", 2), await openPhone("Bo", 5)];

  await test.step("join", async () => {
    for (const phone of phones) await phone.join(host);
  });

  await test.step("walk in the lobby", async () => {
    // The host presses Start once every character has moved, so this also starts the minigame.
    await Promise.all(phones.map((phone, index) => phone.walk(index === 0 ? 70 : -70)));
    await host.event(/^moved /, { occurrence: phones.length });
    expect(await host.event(/^start /)).toBe(`start players=${phones.length}`);
  });

  await test.step("ready up", async () => {
    for (const phone of phones) await phone.readyUp();
    await host.event(/^scene bubbles_and_jellyfishes$/);
  });

  await test.step("play the round", async () => {
    // Swipes before the active phase are rejected by design, so wait for it.
    await host.event(/^phase active$/, { timeout: 60_000 });
    for (const phone of phones) await expect(phone.page.locator("#bubbles-card")).toBeVisible();

    // The host announces the end two seconds early. A swipe that arrives after the round
    // has ended is rejected, and the phone reports that rejection as an error.
    let ending = false;
    host.event(/^round ending$/, { timeout: 5 * 60_000 }).then(
      () => {
        ending = true;
      },
      () => {},
    );
    for (let swipe = 0; !ending; swipe += 1) {
      const [dx, dy] = SWIPES[swipe % SWIPES.length];
      await Promise.all(phones.map((phone) => phone.swipe(dx, dy)));
      if (swipe === 2) for (const phone of phones) await phone.shot("bubbles");
      await phones[0].page.waitForTimeout(600);
    }
    await host.event(/^phase results$/, { timeout: 30_000 });

    // The phones show results only after the host's results snapshot reaches them.
    await phones[0].page.waitForTimeout(1_000);
    for (const phone of phones) {
      expect(
        phone.count("bubbles_trace_result"),
        `${phone.name} had no accepted swipe`,
      ).toBeGreaterThan(0);
      await phone.shot("results");
    }
  });

  await test.step("return to the lobby", async () => {
    await host.event(/^return$/, { timeout: 30_000 });
    await host.event(/^scene lobby$/, { occurrence: 2 });
    for (const phone of phones) {
      await expect(phone.page.locator("#lobby-controller")).toBeVisible();
      await phone.shot("back-in-lobby");
    }
  });

  const rejections = phones.flatMap((phone) =>
    phone.rejections.map((rejection) => `${phone.name}: ${rejection}`),
  );
  if (rejections.length > 0)
    test.info().annotations.push({ type: "rejected input", description: rejections.join("\n") });
});
