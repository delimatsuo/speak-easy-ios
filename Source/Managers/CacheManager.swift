import Foundation

protocol Cacheable {
    var cacheKey: String { get }
    var timestamp: Date { get }
    var dataSize: Int { get }
}

class CacheManager {
    static let shared = CacheManager()
    
    private let memoryCache = NSCache<NSString, CachedItem>()
    private let diskCache: DiskCacheManager
    private let maxMemoryItems = 100
    private let maxMemorySize = 50 * 1024 * 1024 // 50MB
    
    private init() {
        self.diskCache = DiskCacheManager(directory: "universal_translator_cache")
        configureMemoryCache()
    }
    
    func store<T: Cacheable>(_ item: T, key: String) async throws {
        let cachedItem = CachedItem(data: item, key: key, timestamp: item.timestamp)
        
        memoryCache.setObject(cachedItem, forKey: key as NSString)
        
        try await diskCache.store(item, key: key)
    }
    
    func retrieve<T: Cacheable>(key: String, type: T.Type) async -> T? {
        if let cachedItem = memoryCache.object(forKey: key as NSString),
           let item = cachedItem.data as? T {
            return item
        }
        
        guard let item = try? await diskCache.retrieve(key: key, type: type) else {
            return nil
        }
        
        let cachedItem = CachedItem(data: item, key: key, timestamp: item.timestamp)
        memoryCache.setObject(cachedItem, forKey: key as NSString)
        
        return item
    }
    
    func clear() async throws {
        memoryCache.removeAllObjects()
        try await diskCache.clear()
    }
    
    func setMaxSize(_ bytes: Int) {
        diskCache.setMaxSize(bytes)
    }
    
    func getCurrentSize() async -> Int {
        return await diskCache.getCurrentSize()
    }
    
    func cleanupExpired() async throws {
        let keys = await diskCache.getAllKeys()
        let now = Date()
        
        for key in keys {
            if let item = try? await diskCache.retrieve(key: key, type: CachedTranslation.self),
               now.timeIntervalSince(item.timestamp) > 86400 { // 24 hours
                try await diskCache.remove(key: key)
                memoryCache.removeObject(forKey: key as NSString)
            }
        }
    }
    
    private func configureMemoryCache() {
        memoryCache.countLimit = maxMemoryItems
        memoryCache.totalCostLimit = maxMemorySize
    }
}

class CachedItem: NSObject {
    let data: Any
    let key: String
    let timestamp: Date
    
    init(data: Any, key: String, timestamp: Date) {
        self.data = data
        self.key = key
        self.timestamp = timestamp
        super.init()
    }
}

class DiskCacheManager {
    private let directory: URL
    private var maxSize = 200 * 1024 * 1024 // 200MB default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    init(directory: String) {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            fatalError("Unable to access documents directory. This is a critical system failure.")
        }
        self.directory = documentsPath.appendingPathComponent(directory)
        
        try? FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
        
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }
    
    func store<T: Cacheable & Codable>(_ item: T, key: String) async throws {
        let data = try encoder.encode(item)
        let url = directory.appendingPathComponent(key)
        
        try data.write(to: url)
        
        await cleanupIfNeeded()
    }
    
    func retrieve<T: Cacheable & Codable>(key: String, type: T.Type) async throws -> T {
        let url = directory.appendingPathComponent(key)
        let data = try Data(contentsOf: url)
        return try decoder.decode(type, from: data)
    }
    
    func remove(key: String) async throws {
        let url = directory.appendingPathComponent(key)
        try FileManager.default.removeItem(at: url)
    }
    
    func clear() async throws {
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        for file in files {
            try FileManager.default.removeItem(at: file)
        }
    }
    
    func setMaxSize(_ bytes: Int) {
        maxSize = bytes
    }
    
    func getCurrentSize() async -> Int {
        guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        
        var totalSize = 0
        for case let fileURL as URL in enumerator {
            if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
               let fileSize = resourceValues.fileSize {
                totalSize += fileSize
            }
        }
        
        return totalSize
    }
    
    func getAllKeys() async -> [String] {
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return []
        }
        
        return files.map { $0.lastPathComponent }
    }
    
    private func cleanupIfNeeded() async {
        let currentSize = await getCurrentSize()
        
        if currentSize > maxSize {
            guard let files = try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]
            ) else { return }
            
            let sortedFiles = files.sorted { file1, file2 in
                let date1 = (try? file1.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
                let date2 = (try? file2.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
                return date1 < date2
            }
            
            var sizeToDelete = currentSize - (maxSize * 3 / 4)
            
            for file in sortedFiles {
                if sizeToDelete <= 0 { break }
                
                if let resourceValues = try? file.resourceValues(forKeys: [.fileSizeKey]),
                   let fileSize = resourceValues.fileSize {
                    try? FileManager.default.removeItem(at: file)
                    sizeToDelete -= fileSize
                }
            }
        }
    }
}