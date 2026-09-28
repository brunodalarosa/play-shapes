export const CHARACTER_SHAPE = "squircle";
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
];
export const FALLBACK_CHARACTER = { shape: CHARACTER_SHAPE, color: "#598DF2" };
export function defaultJoinFlow() {
    return { screen: "selection", color: CHARACTER_COLORS.find(option => option.id === "blue").hex };
}
export function chooseJoinColor(state, color) {
    return { ...state, color };
}
export function advanceJoinFlow(state) {
    return { ...state, screen: "name" };
}
export function returnToCharacterSelection(state) {
    return { ...state, screen: "selection" };
}
export function createJoinMessage(name, state) {
    return { type: "join", name: name.trim(), character_shape: CHARACTER_SHAPE, character_color: state.color };
}
export function colorOption(hex) {
    if (typeof hex !== "string")
        return undefined;
    return CHARACTER_COLORS.find(option => option.hex.toUpperCase() === hex.toUpperCase());
}
