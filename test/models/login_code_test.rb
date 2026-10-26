require "test_helper"

class LoginCodeTest < ActiveSupport::TestCase
  test "codes are hashed expire and can be consumed once" do
    challenge, code = LoginCode.issue("alex@example.test", "127.0.0.1")
    assert_not_equal code, challenge.digest
    assert challenge.consume(code)
    assert_not challenge.consume(code)
    expired, expired_code = LoginCode.issue("alex@example.test", "127.0.0.1")
    travel 11.minutes do
      assert_not expired.consume(expired_code)
    end
  end

  test "attempt limits and persistent email and IP throttles" do
    challenge, code = LoginCode.issue("alex@example.test", "127.0.0.1")
    5.times { assert_not challenge.consume("invalid") }
    assert_not challenge.consume(code)
    2.times { assert LoginCode.issue("alex@example.test", "127.0.0.1") }
    assert_nil LoginCode.issue("alex@example.test", "other")
    17.times { |index| assert LoginCode.issue("#{index}@example.test", "127.0.0.1") }
    assert_nil LoginCode.issue("another@example.test", "127.0.0.1")
  end
end
