require "../../rate_limiter.rb"

describe RateLimiter do
  TIME_WINDOW = 30
  MAX_REQUESTS = 3

  before(:example) do
    @rate_limiter = RateLimiter.new TIME_WINDOW, MAX_REQUESTS
  end

  describe "#allow_request?" do
    before(:example) do
      @user_id = 44832
      @other_user_id = 54584

      @ancient_timestamp = Time.utc(2000, "jan", 1, 0, 0, 0).to_i
      @recent_timestamp  = Time.utc(2010, "mar", 12, 10, 30, 0).to_i
    end
    
    it "allows request with any timestamp for a new user" do
      expect(@rate_limiter.allow_request?(@ancient_timestamp + 1, @user_id)).to eq(true)
    end

    it "allows request more than time window after oldest request" do
      
      @rate_limiter.record_request_time(@recent_timestamp, @user_id)
      @rate_limiter.record_request_time(@recent_timestamp + 5, @user_id)
      @rate_limiter.record_request_time(@recent_timestamp + 10, @user_id)

      expect(@rate_limiter.allow_request?(@recent_timestamp + TIME_WINDOW, @user_id)).to eq(true)
    end

    it "does not allow requests less than time window after oldest request" do
      @rate_limiter.record_request_time(@recent_timestamp, @user_id)
      @rate_limiter.record_request_time(@recent_timestamp + 5, @user_id)
      @rate_limiter.record_request_time(@recent_timestamp + 10, @user_id)

      expect(@rate_limiter.allow_request?(@recent_timestamp + TIME_WINDOW - 1, @user_id)).to eq(false)
    end

    it "lets old requests fall off the end of the time window" do
      @rate_limiter.record_request_time(@recent_timestamp - 5, @user_id)
      @rate_limiter.record_request_time(@recent_timestamp, @user_id)
      @rate_limiter.record_request_time(@recent_timestamp + 5, @user_id)
      @rate_limiter.record_request_time(@recent_timestamp + 10, @user_id)

      # request is acceptable if it is more than 30 seconds from the *third* most recent request
      expect(@rate_limiter.allow_request?(@recent_timestamp + TIME_WINDOW - 1, @user_id)).to eq(false)
      expect(@rate_limiter.allow_request?(@recent_timestamp + TIME_WINDOW, @user_id)).to eq(true)
    end

    it "keeps track of request times separately for each user" do
      @rate_limiter.record_request_time(@recent_timestamp, @user_id)
      @rate_limiter.record_request_time(@recent_timestamp + 5, @user_id)
      @rate_limiter.record_request_time(@recent_timestamp + 10, @user_id)

      expect(@rate_limiter.allow_request?(@recent_timestamp + TIME_WINDOW - 1, @other_user_id)).to eq(true)
    end
  end

  describe "#record_request_time" do
    before(:example) do
      @user_id = 44832
      @first_request_timestamp = Time.utc(2000,"jan",1,0,0,0).to_i
    end

    it "does not allow time travel" do
      @rate_limiter.record_request_time(@first_request_timestamp, @user_id)

      expect {
        @rate_limiter.record_request_time(@first_request_timestamp - 1, @user_id)
      }.to raise_error(RuntimeError)
    end
  end
end
