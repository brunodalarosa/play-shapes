export const CHARACTER_SHAPES = ["square", "circle", "squircle", "rhombus"];
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
export const FALLBACK_CHARACTER = { shape: "circle", color: "#598DF2" };
export function defaultJoinFlow() {
    return { screen: "selection", shape: FALLBACK_CHARACTER.shape, color: CHARACTER_COLORS.find(option => option.id === "blue").hex };
}
export function cycleJoinShape(state, offset) {
    return { ...state, shape: shapeAtOffset(state.shape, offset) };
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
    return { type: "join", name: name.trim(), character_shape: state.shape, character_color: state.color };
}
export function isCharacterShape(value) {
    return typeof value === "string" && CHARACTER_SHAPES.includes(value);
}
export function shapeAtOffset(current, offset) {
    const currentIndex = CHARACTER_SHAPES.indexOf(current);
    const nextIndex = ((currentIndex + offset) % CHARACTER_SHAPES.length + CHARACTER_SHAPES.length) % CHARACTER_SHAPES.length;
    return CHARACTER_SHAPES[nextIndex];
}
export function colorOption(hex) {
    if (typeof hex !== "string")
        return undefined;
    return CHARACTER_COLORS.find(option => option.hex.toUpperCase() === hex.toUpperCase());
}
export function bodyAssetPath(shape) {
    return `/shape-${shape}.png`;
}
