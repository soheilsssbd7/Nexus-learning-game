import assert from "node:assert/strict";
import test from "node:test";
import { isGamePlayerId, isUuidV5, playerIdToUuid, uuidV5, NEXUS_UUID_NAMESPACE } from "../src/ids.js";

test("شکلِ §۲ پذیرفته و بقیه رد می‌شود ✓", () => {
  assert.equal(isGamePlayerId("p_193f2a7e"), true);
  for (const bad of ["p_193F2A7E", "193f2a7e", "p_193f2a7", "player_193f2a7e", "", "p_"]) {
    assert.equal(isGamePlayerId(bad), false, `«${bad}» نباید بگذرد ✗✓`);
  }
});

test("نگاشتِ player_id ⇒ UUIDv5 قطعی است (بی‌جدولِ mapping ✓ADR-063)", () => {
  const a = playerIdToUuid("p_193f2a7e");
  const b = playerIdToUuid("p_193f2a7e");
  assert.equal(a, b, "یک رشته ⇒ یک uuid، هر بار ✓ (وگرنه هر sync یک بازیکنِ جدید می‌ساخت ✗✗)");
  assert.equal(isUuidV5(a), true, `شکلِ uuid v5 نیست: ${a} ✗`);
  assert.notEqual(a, playerIdToUuid("p_deadbeef"), "دو بازیکن ⇒ دو uuid ✓");
});

test("id نامعتبر نمی‌تواند بی‌صدا به uuid نگاشت شود ✗✓", () => {
  assert.throws(() => playerIdToUuid("p_ZZZZZZZZ"), /نامعتبر/);
});

test("uuidV5 با فضای‌نامِ دیگر فرق می‌کند و بایت‌های نسخه/واریانت درست است ✓", () => {
  const ns2 = "00000000-0000-5000-8000-000000000000";
  assert.notEqual(uuidV5("x", NEXUS_UUID_NAMESPACE), uuidV5("x", ns2));
  const hex = uuidV5("x").replace(/-/g, "");
  assert.equal(hex[12], "5", "نسخه ۵ ✓");
  assert.ok(["8", "9", "a", "b"].includes(hex[16] ?? ""), "واریانت RFC4122 ✓");
});
