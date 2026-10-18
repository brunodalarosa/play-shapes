import { expect, test } from "./fixtures";

const SWIPES: [number, number][] = [
  [120, 0],
  [0, 120],
  [-120, 0],
  [0, -120],
  [90, 90],
  [-90, -90],
];

test.use({ game: "bubbles_3d" });

test("two phones join, play a Bubbles and jellyfishes 3D round and return to the lobby", async ({
  host,
  openPhone,
}) => {
  const phones = [await openPhone("Ana", 2), await openPhone("Bo", 5)];

  await test.step("join", async () => {
    for (const phone of phones) await phone.join(host);
  });

  await test.step("walk in the lobby", async () => {
    await Promise.all(phones.map((phone, index) => phone.walk(index === 0 ? 70 : -70)));
    await host.event(/^moved /, { occurrence: phones.length });
    await host.event(/^selected bubbles_3d$/);
    expect(await host.event(/^start /)).toBe(`start players=${phones.length}`);
  });

  await test.step("ready up", async () => {
    for (const phone of phones) await phone.readyUp();
    await host.event(/^scene 3d_bubbles$/);
  });

  await test.step("play the round", async () => {
    await host.event(/^phase active$/, { timeout: 60_000 });
    for (const phone of phones) {
      await expect(phone.page.locator("#bubbles-3d-card")).toBeVisible();
      // The 3D view replaces the flat fallback once three.js and the models have loaded.
      await expect(phone.page.locator("#bubbles-3d-visual")).toBeVisible();
      await expect(phone.page.locator("#bubbles-3d-fallback")).toBeHidden();
    }

    // The host announces the end two seconds early, so no swipe arrives after zero.
    let ending = false;
    host.event(/^round ending$/, { timeout: 5 * 60_000 }).then(
      () => {
        ending = true;
      },
      () => {},
    );
    for (let swipe = 0; !ending; swipe += 1) {
      const [dx, dy] = SWIPES[swipe % SWIPES.length];
      await Promise.all(phones.map((phone) => phone.swipe(dx, dy, "#bubbles-3d-card")));
      if (swipe === 2) for (const phone of phones) await phone.shot("bubbles-3d");
      await phones[0].page.waitForTimeout(600);
    }
    await host.event(/^phase results$/, { timeout: 30_000 });
    await phones[0].page.waitForTimeout(1_000);
    for (const phone of phones) {
      expect(
        phone.count("bubbles_3d_release_result"),
        `${phone.name} had no answered swipe`,
      ).toBeGreaterThan(0);
      expect(phone.count("bubbles_3d_visual"), `${phone.name} saw no visuals`).toBeGreaterThan(0);
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
