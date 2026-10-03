export const CHARACTER_SHAPE = "squircle" as const;

export const CHARACTER_COLORS = [
  { id: "red", name: "Red", hex: "#E53935" },
  { id: "orange", name: "Orange", hex: "#F57C00" },
  { id: "golden_yellow", name: "Golden Yellow", hex: "#FBC02D" },
  { id: "green", name: "Green", hex: "#43A047" },
  { id: "cyan", name: "Cyan", hex: "#00ACC1" },
  { id: "blue", name: "Blue", hex: "#1E88E5" },
  { id: "indigo", name: "Indigo", hex: "#3949AB" },
  { id: "purple", name: "Purple", hex: "#8E24AA" },
  { id: "pink", name: "Pink", hex: "#EC407A" },
  { id: "brown", name: "Brown", hex: "#8D6E63" },
] as const;
export type CharacterColor = (typeof CHARACTER_COLORS)[number]["hex"];

export const FALLBACK_CHARACTER = { shape: CHARACTER_SHAPE, color: "#598DF2" } as const;
export type JoinScreen = "selection" | "name";
export type JoinFlowState = { screen: JoinScreen; color: CharacterColor };

export function defaultJoinFlow(): JoinFlowState {
  return {
    screen: "selection",
    color: CHARACTER_COLORS.find((option) => option.id === "blue")!.hex,
  };
}

export function chooseJoinColor(state: JoinFlowState, color: CharacterColor): JoinFlowState {
  return { ...state, color };
}

export function advanceJoinFlow(state: JoinFlowState): JoinFlowState {
  return { ...state, screen: "name" };
}

export function returnToCharacterSelection(state: JoinFlowState): JoinFlowState {
  return { ...state, screen: "selection" };
}

export function createJoinMessage(name: string, state: JoinFlowState) {
  return {
    type: "join",
    name: name.trim(),
    character_shape: CHARACTER_SHAPE,
    character_color: state.color,
  } as const;
}

export function colorOption(hex: unknown): (typeof CHARACTER_COLORS)[number] | undefined {
  if (typeof hex !== "string") return undefined;
  return CHARACTER_COLORS.find((option) => option.hex.toUpperCase() === hex.toUpperCase());
}
