# Wolf - Ruby on Rails Staff Engineer Technical Assessment

## Algorithmic Challenge: Rate Limiter

### by Henrique

Hi everybody at Wolf! This is my technical submission. Please let me know what you
think.

### Environment
This submission was developed and tested on Ruby 2.7.0 and Ubuntu.

### How to run

The main class file can be found at ```rate_limiter.rb``` The RSpec test file can be found at ```spec/integration/rate_limiter_spec.rb```

To run the unit tests type ```cd spec/integration``` and ```rspec rate_limiter_spec.rb``` from the main directory. The tests won't work if you try to them directly from the main directory.

### General observations
A few observations regarding the problem statement and potential solutions. Firstly we should note that this is a coding challenge and not code to be run on a production system. On a real implementation we would want build in scalability and the ability to scale up using more instances. This would mean that the list of request timestamps for a particular user should be stored in a durable location, such as Redis or other NoSQL system, and not in memory on the rate limiter instance. This allows us to spin up and shut down instances without worrying about losing data. Since this is a coding challenge I've just stored the list of request times in memory as an instance variable of the `RateLimiter` class.

### Use scenarios
It's a bit ambiguous from the problem description how the rate limiter class gets access to the actual list of request timestamps. Is the array of requests passed into a method? Do they get added in order one-by-one? I've implemented the `RateLimiter` class with a `record_request_time(timestamp, user_id)` method.

The idea is as requests come in they get recorded, and `allow_request?` reflects the most recent state of the api.

If you wanted to slurp up the entire list of requests at once (a bit unrealistic in a real system), you would do something like

```
api_request_times.each do |request|
  timestamp = request['timestamp']
  user_id = request['user_id']

  rate_limiter.record_request_time(timestamp, user_id)
end
```

and then you can

```
rate_limiter.allow_access?(my_timestamp, some_user_id)
```

all you like.

More realistically, you would do something like

```
if rate_limiter.allow_access?(my_timestamp, some_user_id)
  rate_limiter.record_request_time(my_timestamp, some_user_id)
  call_api(...)
else
  raise "Too many requests"
end
```

in your controller.


### Sliding vs. dynamic window

The question of sliding vs. fixed windows is important. Implementing a fixed window is pretty simple. Just keep a running count of how many requests came in the current window and reset the count to 0 when the clock moves to a new window. If the number of requests in the current window is too high, deny the request.

Dynamic windows are a bit tricker to implement. If you allow N requests per T second window, you need to keep a list of the N most recent requests. Assuming the clock is moving forward and the request timestamps don't arrive out of order, you shove the most recent timestamp to the front of the list and drop the oldest timestamp out the back. An incoming request is allowed if it is at least T seconds ahead of the last timestamp on the list.

It gets trickier if timestamps can arrive out of order. Then you need to insert the new timestamp in place in the list so that it remains sorted. If the new timestamp is older than the oldest timestamp in the list (the Nth element), then it is ignored.

For purposes of simplicity we have ignored this possibility, and simply raise an exception if a new request comes in with a timestamp prior to the most recent previous timestamp.  This might be a bit unrealistic on production systems where a second or two of latency might be common, but for the sake of keeping things simple this code assumes that timestamps arrive in non-decreasing order.

If timestamps do arrive in random order, we'd have to have some way of keeping them ordered. The `OrderedSet` class has been removed from the Ruby standard library, so in this case you might want to use a red-black tree.  Red-black trees make it easy to find the largest elements in a list, and have O(log n) insertion time. 

You could also just sort the list of MAX_TIMESTAMPS elements and drop the lowest, which despite sorting being O(n log n) is technically O(1) with respect to the numberof requests since MAX_TIMESTAMPS is a constant.

Whether there is the possibility of an off-by-one error in the window logic. Is a request at t=30 allowed if the oldest request happened at t=0? Is the cutoff 30-0 or 30-0+1? This is a matter of personal taste, but in the `RateLimiter` class t=30 is allowed in this case.

New users are initialized with 3 imaginary requests from Jan 1, 1970 (timestamp=0). It just makes the logic simpler and eliminates the need to deal with edge cases. The end result is the same.

### Memory usage

In a real production system memory pools would be a concern.  A memory pool is different from a memory leak in that in a memory leak the reference to the memory is lost, whereas in a memory pool the reference is accessible but just never deallocated.

The `@request_times` variable will grow and grow and grow and eventually exhaust all available memory.

You could in principle have a purge method which goes through and eliminates entries with old timestamps, or you could store it in a NoSQL database and have it discard records that haven't been used in the last five minutes or so.

### Time complexity

The algorithm used in `record_request` just pushes an item onto the end of an array and drops the first element. Both operations are amortized O(1). You'd think that `Array.shift` would be O(n), since you have to scoot all the elements down the array, but I looked it up and since Ruby 2.0.0 it has amortized O(1) time complexity. That's because the Ruby people did a sneaky optimization and the first element of the array isn't the **real** first element. The first element is actually a pointer, and the `shift` operation just moves that pointer instead of actually shifting. Very clever, although from time to time they have to do some housekeeping to prevent excess memory usage.

The algorithm is correct as long as timestamps come in order, and still correct if they don't because the method refuses to record the timestamp.

The method `allow_request?` just looks up the oldest timestamp and compares it to the new timestamp and the 30 second limit. It's strickly O(1)

`record_request` and `allow_request?` both look up users in a hash indexed by user id. This is an amortized O(1) operation, although hash lookups technically have O(n) worst case performance if you just happen to get unlucky and all your items map to the same hash key.  For our purposes we'll call it O(1)

The class as implemented should run into no performance issues since all methods are O(1) with respect to the number of requests. If you allowed out of order timestamps and used a red-black tree the `record_request` method would have O(log n) time complexity.

### Test suite

The test suite tests for various potential bugs such as users not being initialized with timestamps in the far past, one user's timestamps affecting another user, the time window not being computer correctly, and so on.


### Thank you

Thanks for taking the time to consider my application. I'm curious to know what you thought of my implementation.

Bye-bye

Henrique



  

