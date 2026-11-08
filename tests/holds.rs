// A harness whose assertion holds for every input Kani tries within its bound.
#[kani::proof]
fn doubling_is_even() {
    let x: u8 = kani::any();
    kani::assume(x < 100);
    assert!((x as u16 * 2) % 2 == 0);
}
