import Foundation

class RateLimiter {
    private let maxRequestsPerMinute = 60
    private var requestTimestamps: [Date] = []
    private let queue = DispatchQueue(label: "rate.limiter.queue")
    
    func canMakeRequest() -> Bool {
        queue.sync {
            let now = Date()
            let oneMinuteAgo = now.addingTimeInterval(-60)
            
            requestTimestamps.removeAll { $0 < oneMinuteAgo }
            
            return requestTimestamps.count < maxRequestsPerMinute
        }
    }
    
    func recordRequest() {
        queue.async {
            self.requestTimestamps.append(Date())
        }
    }
    
    func timeUntilNextRequest() -> TimeInterval? {
        queue.sync {
            guard requestTimestamps.count >= maxRequestsPerMinute else {
                return nil
            }
            
            guard let oldestRequest = requestTimestamps.first else {
                print("❌ [RateLimiter] Unexpected empty timestamps array")
                return nil
            }
            let availableTime = oldestRequest.addingTimeInterval(60)
            return availableTime.timeIntervalSince(Date())
        }
    }
}

class ExponentialBackoff {
    private var retryCount = 0
    private let maxRetries = 5
    private let baseDelay: TimeInterval = 1.0
    private let maxDelay: TimeInterval = 32.0
    
    func nextDelay() -> TimeInterval? {
        guard retryCount < maxRetries else { return nil }
        
        let delay = min(baseDelay * pow(2.0, Double(retryCount)), maxDelay)
        retryCount += 1
        
        let jitter = delay * 0.1 * (Double.random(in: -1...1))
        return delay + jitter
    }
    
    func reset() {
        retryCount = 0
    }
}