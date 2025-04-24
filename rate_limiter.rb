class RateLimiter

  LONG_AGO_TIMESTAMP = 0    # 0:00 January 1, 1970 UTC
 
  def initialize(time_window, max_requests)
    # previous requests. user_id is the key,
    # an array of timestamps is the value
    @request_times = Hash.new

    @time_window = time_window
    @max_requests = max_requests
  end

  def allow_request?(timestamp, user_id)
    start_of_window = timestamp - @time_window
    
    oldest_request_time(user_id) <= start_of_window
  end

  # this function is used to keep track of previous request
  # times. attempting to record a request prior to the most
  # recent request raises an exception.
  def record_request_time(timestamp, user_id)
    initialize_user_request_times user_id
 
    if timestamp >= newest_request_time(user_id)
      @request_times[user_id].push timestamp
      @request_times[user_id].shift
    else
      raise "Time travel not allowed. timestamp '#{timestamp}' " +
            " for user '#{user_id}' before most recent timestamp "
    end

    timestamp
  end

  private

  def newest_request_time(user_id)
    if @request_times.has_key? user_id
      @request_times[user_id].last
    else
      LONG_AGO_TIMESTAMP
    end
  end

  def oldest_request_time(user_id)
    if @request_times.has_key? user_id
      @request_times[user_id].first
    else
      LONG_AGO_TIMESTAMP
    end
  end

  # initializes request times to [0, 0, ..., 0] for new user
  # array length is max number of requests in window
  def initialize_user_request_times(user_id)
    @request_times[user_id] ||= Array.new(@max_requests, LONG_AGO_TIMESTAMP)
  end
end
