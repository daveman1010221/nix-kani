// A harness whose assertion fails for some input: Kani must find it.
#[kani::proof]
fn not_every_byte_is_small() {
    let x: u8 = kani::any();
    assert!(x < 200);
}
