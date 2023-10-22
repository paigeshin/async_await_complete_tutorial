### Reference

1. https://www.viget.com/articles/concurrency-multithreading-in-ios/

2. https://ali-akhtar.medium.com/concurrency-in-swift-grand-central-dispatch-part-1-945ff05e8863

3. https://www.swiftbysundell.com/articles/task-based-concurrency-in-swift/

4. https://cocoacasts.com/swift-and-cocoa-fundamentals-threads-queues-and-concurrency

5. https://www.hackingwithswift.com/quick-start/concurrency/whats-the-difference-between-a-task-and-a-detached-task

6. https://github.com/apple/swift-evolution/blob/main/proposals/0317-async-let.md

7. https://github.com/apple/swift-evolution/blob/main/proposals/0304-structured-concurrency.md

8. https://developer.apple.com/videos/play/wwdc2021/10134/

9. https://medium.com/swiftcairo/avoiding-race-conditions-in-swift-9ccef0ec0b26

### DispatchQueue Global, Concurrent

- User Interactive => User Interface
- User Initiated => Prevent users from actively using your app
- Default => System decides prioirity
- Utility
- Background => Do something in the background
- Unspecified => No Priority Setting

### Serial Queue

```swift
let queue = DispatchQueue(label: "SerialQueue")

queue.async {
    print("task1 started")
    sleep(3)
    // this task is executed first
    print("task1 finished")
}

queue.async {
    print("task2 started")
    sleep(3)
    // this task is executed seconds
    print("task2 finished")
}
```

### Concurrent Queue

```swift
let queue = DispatchQueue(label: "ConcurrentQueue", attributes: .concurrent)

queue.async {

}

queue.async {

}

// Tasks will start in the order they are added but they can finish in any order

```

### Correct Way to use BackgroundQueue

```swift
            DispatchQueue.global().async {
                // download the image
                DispatchQueue.main.async {
                    // refresh the UI
                }
            }
```

### Continuation

The main point of continuation and to use continuation is to expose our existing functions

```swift
func getPosts() async throws -> [Post] {
    return await withCheckedContinuation { continuation in
        getPosts { posts in
            continuation.resume(returning: posts)
        }
    }
}
```

### Using Continuation

```swift
import UIKit

struct Post: Decodable {
    let title: String
}

enum NetworkError: Error {
    case badURL
    case noData
    case decodingError
}

func getPosts(completion: @escaping (Result<[Post], NetworkError>) -> Void) {

    guard let url = URL(string: "https://jsonplaceholder.typicode.com/posts") else {
        completion(.failure(.badURL))
        return
    }
    URLSession.shared.dataTask(with: url) { data, _ , error in
        guard let data, error == nil else {
            completion(.failure(.noData))
            return
        }

        let posts = try? JSONDecoder().decode([Post].self, from: data)
        completion(.success(posts ?? []))

    }.resume()

}

getPosts { result in
    switch result {
    case .success(let posts): print(posts)
    case .failure(let error): print(error)
    }
}

func getPosts() async throws -> [Post] {
    return try await withCheckedThrowingContinuation { continuation in
        getPosts { result in
            switch result {
            case .success(let posts): continuation.resume(returning: posts)
            case .failure(let error): continuation.resume(throwing: error)
            }
        }
    }
}


Task {
    do {
        let posts = try await getPosts()
        print(posts)
    } catch {
        print(error)
    }

}



```

### Structured Concurrency

- async let
- TaskGroup
- Unstructured Tasks
- Detached Tasks
- Task Cancellation

### Async Let

- Problem
  => Wait for another task that doesn't have dependency

```swift
    guard let equifaxURL = Constants.Urls.equifaX(userID: userID),
          let experianURL = Constants.Urls.EXPERIAN(userID: userID)
    else {
        throw NetworkError.badURL
    }

    let (equiFaxData, _ ) = try await URLSession.shared.data(from: equifaxURL)
    let (experianData, _ ) = try await URLSession.shared.data(from: experianURL)
```

- Solution

```swift
    // Concurrently Executing
    async let (equiFaxData, _ ) = URLSession.shared.data(from: equifaxURL)
    async let (experianData, _ ) = URLSession.shared.data(from: experianURL)

    // Capture Result
    let equiData = try await equiFaxData
    let experData = try await experianData
```

### Loop All Elements When Async Operation encounters an error

- This code stops executing when encountering error

```swift
    for _ in 1...5 {
        let result = try await myTaskMethod()
    }

```

- This code continues executing when encountering error

```swift
    for _ in 1...5 {
        do {
            // Task.checkCancellation() => Make sure all tasks are running
            try Task.checkCancellation()
            let result = try await myTaskMethod()
        } catch {
            print(error)
        }
    }
```

```swift
Task {
    for _ in 1...5 {
        do {
            // Task.checkCancellation() => Make sure all tasks are running
            try Task.checkCancellation()
            let result = try await myTaskMethod()
        } catch {
            print(error)
        }
    }

    // This code stops executing when encountering error
    for _ in 1...5 {
        let result = try await myTaskMethod()
    }

}
```

### Concurrency Using Task Group

- Getting information of individual user information is executed concurrently. `

```swift
func getUserInfo(id: String) async throws -> String {
    return ""
}

func getAllUserInfo(ids: [String]) async throws -> [String] {

    var userInfos: [String] = []

    try await withThrowingTaskGroup(of: String.self) { group in
        for id in ids {
            group.addTask {
                let userInfo = try await getUserInfo(id: id)
                return userInfo
            }
        }
        for try await userInfo in group {
            userInfos.append(userInfo)
        }
    }

    return userInfos
}

```

### Unstructured Task

Task {
await doSomething()
}

### Detached Task

Generally don't use `detached Task`

```swift
// Nothing is inherited
Task.detached(priority: .background) {
    let thumbnails =  await fetchThumbnail() {
        writeToCache(images: thumbnails)
    }
}

Task(priority: .background, operation: {
    // Child task inherits the same priority, here is `Background`
    Task {
        print(Task.currentPriority == .background) // true
    }

})
```

### async let vs TaskGroup

=> Use TaskGroup if you don't know how many concurrent operations are required

### AsyncSequence

```swift
Task {
    // print out line by line
    for line in await endPointURL.allLines() {
        print("One By One Task => \(line)")
    }

}

Task {
    // it doesn't wait all data to be downloaded
    // Once data is available, it captures right away
    for try await line in endPointURL.lines {
        print("Concurrent Task => \(line)")
    }
}
```

```swift
import UIKit

extension URL {
    func allLines() async -> Lines {
        Lines(url: self)
    }
}

struct Lines: Sequence {

    let url: URL

    func makeIterator() -> some IteratorProtocol {
        let lines = (try? String(contentsOf: self.url))?.split(separator: "\n") ?? []
        return LinesIterator(lines: lines)
    }

}

struct LinesIterator: IteratorProtocol {

    typealias Element = String // Returning Element
    var lines: [String.SubSequence]

    mutating func next() -> Element? {
        if self.lines.isEmpty { return nil }
        return String(self.lines.removeFirst()) // removeFirst returns removed element
    }

}

let endPointURL = URL(string: "https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_month.csv")!


Task {
    // print out line by line
    for line in await endPointURL.allLines() {
        print("One By One Task => \(line)")
    }

}

Task {
    // it doesn't wait all data to be downloaded
    // Once data is available, it captures right away
    for try await line in endPointURL.lines {
        print("Concurrent Task => \(line)")
    }
}

```

### Built In Async Framework

```swift
// File Handle
let paths = Bundle.main.paths(forResourcesOfType: "txt", inDirectory: nil)

let fileHandle = FileHandle(forReadingAtPath: paths[0])

Task {
    for try await line in fileHandle!.bytes {
        print(line) // byte
    }
}

// URL
Task {
    let url = URL(filePath: paths[0])
    for try await line in url.lines {
        print(line) // contents
    }
}

// URL Byte
Task {
    let url = URL(string: "https://www.google.com")!
    let (bytes, _) = try await URLSession.shared.bytes(from: url)
    for try await byte in bytes {
        print(byte) // byte
    }
}

// Notification
Task {
    let center = NotificationCenter.default
    let _ = await center.notifications(named: UIApplication.didEnterBackgroundNotification).first { notification in
        guard let key = (notification.userInfo?["Key"]) as? String else { return false }
        return key == "SomeValue"
    }
}

```

### AsyncStream

- AsyncStream has great operation method like `drop()`, `filter()`, `map()` and more..

[Old API Example]

```swift
let bitcoinPriceMonitor = BitcoinPriceMonitor()
bitcoinPriceMonitor.priceHandler = { price in
    print(price)
}
bitcoinPriceMonitor.startUpdating()
```

[New Async Stream API Example]

```swift
let bitcoinPriceStream = AsyncStream(Double.self) { continuation in
    let bitcoinPriceMonitor = BitcoinPriceMonitor()
    bitcoinPriceMonitor.priceHandler = { price in
        continuation.yield(price)
    }
//    continuation.onTermination = { _ in }
    bitcoinPriceMonitor.startUpdating()
}

Task {
    for await bitcoinPrice in bitcoinPriceStream {
        print(bitcoinPrice)
    }
}

```

```swift
import UIKit

class BitcoinPriceMonitor {

    var price = 0.0
    var timer: Timer?
    var priceHandler: (Double) -> Void = { _ in }

    @objc
    func getPrice() {
        self.priceHandler(Double.random(in: 20000...40000))
    }

    func startUpdating() {
        self.timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(self.getPrice), userInfo: nil, repeats: true)
    }

    func stopUpdating() {
        self.timer?.invalidate()
    }

}

// Old API
let bitcoinPriceMonitor = BitcoinPriceMonitor()
bitcoinPriceMonitor.priceHandler = { price in
    print(price)
}
bitcoinPriceMonitor.startUpdating()

// New Async API
let bitcoinPriceStream = AsyncStream(Double.self) { continuation in
    let bitcoinPriceMonitor = BitcoinPriceMonitor()
    bitcoinPriceMonitor.priceHandler = { price in
        continuation.yield(price)
    }
//    continuation.onTermination = { _ in }
    bitcoinPriceMonitor.startUpdating()
}

Task {
    for await bitcoinPrice in bitcoinPriceStream {
        print(bitcoinPrice)
    }
}

```

### Prevent Concurrent Issue

- This makes sure only one thread can acess the resource
- Other thread must wait until the previous operation is finished

```swift
let lock = NSLock()
lock.lock()
// do something
lock.unlock()
```

```swift
class BankAccount {

    var balance: Double
    let lock = NSLock()

    init(balance: Double) {
        self.balance = balance
    }

    // Make sure only one thread can go inside
    func withdraw(_ amount: Double) {

        self.lock.lock()
        if self.balance >= amount {

            let processingTime = UInt32.random(in: 0...3)
            print("[Withdraw] Processing for \(amount) \(processingTime) seconds")
            sleep(processingTime)
            print("Withdrawing \(amount) from account")
            self.balance -= amount
            print("Balance is \(self.balance)")
        }
        self.lock.unlock()

    }

}

let bankAccount = BankAccount(balance: 500)

let queue = DispatchQueue(label: "ConcurrentQueue", attributes: .concurrent)

queue.async {
    bankAccount.withdraw(300)
}

queue.async {
    bankAccount.withdraw(500)
}

```

### Actors

- Protect mutable state
- Accessing Actor isolated states
- MainActor
- Nonisolated

### Actor

- Actor guarantees "Sequential Operation" => Block Another Thread until the previous task is finished in Concurrent Tasks
- Actor can't mutate other instance. Or you will see an error message "Actor-isolated instance method can not be referenced on a non-isolated actor instance."
- Actor forces only one thread access.

[Concurrency Problem]

```swift
class Counter {
    var value = 0

    func increment() -> Int {
        self.value += 1
        return self.value
    }

}

let counter = Counter()
DispatchQueue.concurrentPerform(iterations: 100) { _ in
    print(counter.increment())
    // Sequence messted up
    // 5
    // 3
    // 10
    // ...
}

```

[Solution with Actor]

```swift
// actor forces only one thread access
actor Counter {
    var value = 0

    func increment() -> Int {
        self.value += 1
        return self.value
    }

}

let counter = Counter()
DispatchQueue.concurrentPerform(iterations: 100) { _ in
    Task {
        print(await counter.increment())
        // printed one by one
        // 1
        // 2
        // 3
        // ...
    }

}
```

```swift
import UIKit

actor BankAccount {

    var balance: Double

    init(balance: Double) {
        self.balance = balance
    }

    func withdraw(_ amount: Double) {
        if self.balance >= amount {
            let processingTime = UInt32.random(in: 0...3)
            print("[Withdraw] Processing for \(amount) \(processingTime) seconds")
            sleep(processingTime)
            print("Withdrawing \(amount) from account")
            self.balance -= amount
            print("Balance is \(self.balance)")
        }
    }

}

let bankAccount = BankAccount(balance: 500)


Task.detached {
    await bankAccount.withdraw(300)
}

Task.detached {
    await bankAccount.withdraw(500)
}

```

- Actor can't mutate other instance. Or you will see an error message "Actor-isolated instance method can not be referenced on a non-isolated actor instance."
  - Put async await keywords if you want to modify it.
- Constant doesn't have any effect on Concurrency Problems because it can't be changed outside.
- Only the things that can be changed outside matter in the concurrency problems.

```swift
 func transfer(amount: Double, to other: BankAccount) async throws {
        if amount > balance {
            throw BankError.insufficientFunds(amount)
        }

        balance -= amount
        await other.deposit(amount)

        print(other.accountNumber)
        print("Current Account: \(balance), Other Account: \(await other.balance)")
    }
```

```swift
enum BankError: Error {
    case insufficientFunds(Double)
}

actor BankAccount {

    // accountNumber doesn't have any issue with concurrency problems, because it's a constant
    // Things that can be changed outside
    let accountNumber: Int
    var balance: Double

    init(accountNumber: Int, balance: Double) {
        self.accountNumber = accountNumber
        self.balance = balance
    }

    func deposit(_ amount: Double) {
        balance += amount
    }

    func transfer(amount: Double, to other: BankAccount) async throws {
        if amount > balance {
            throw BankError.insufficientFunds(amount)
        }

        balance -= amount
        await other.deposit(amount)

        print(other.accountNumber)
        print("Current Account: \(balance), Other Account: \(await other.balance)")
    }
}


struct ContentView: View {

    var body: some View {
        Button {

            let bankAccount = BankAccount(accountNumber: 123, balance: 500)
            let otherAccount = BankAccount(accountNumber: 456, balance: 100)

            DispatchQueue.concurrentPerform(iterations: 100) { _ in
                Task {
                    try? await bankAccount.transfer(amount: 300, to: otherAccount)
                }
            }

        } label: {
            Text("Transfer")
        }

    }
}
```

### Non-isolated keywords

```swift
    // This function doesn't change any state of the `actor`
    // But it still needs `async await` keywords to call it
    // In this case, you can put "non-isolated" keywords
    nonisolated func getCurrentAPR() -> Double {
        return 0.2
    }
```

```swift
actor BankAccount {

    // accountNumber doesn't have any issue with concurrency problems, because it's a constant
    // Things that can be changed outside
    let accountNumber: Int
    var balance: Double

    init(accountNumber: Int, balance: Double) {
        self.accountNumber = accountNumber
        self.balance = balance
    }

    // This function doesn't change any state of the `actor`
    // But it still needs `async await` keywords to call it
    // In this case, you can put "non-isolated" keywords
    nonisolated func getCurrentAPR() -> Double {
        // self.balance = 3000 => impossible to change because it's marked as `nonisolated`
        return 0.2
    }

    func deposit(_ amount: Double) {
        balance += amount
    }

    func transfer(amount: Double, to other: BankAccount) async throws {
        if amount > balance {
            throw BankError.insufficientFunds(amount)
        }

        balance -= amount
        await other.deposit(amount)

        print(other.accountNumber)
        print("Current Account: \(balance), Other Account: \(await other.balance)")
    }
}
```

### MainActor

- @MainActor only works only on async await operations
- Callbacks, Closures don't work even your class is makred as @MainActor

```swift
Task {
    await MainActor.run {
        self.items = items
    }
}
```

```swift
WebService().getAll(url: url) { result in
    switch result {
        case .success(let items):
        Task {
            await MainActor.run {
                self.items = items
            }
        }

        case .failure(let error):
        print(error)
    }
}

```

```swift
func getAll(url: URL, completion: @MainActor @escaping (Result<Item>, NetworkError) -> Void) {
    URLSession.shared.dataTask(with: url) { data, _ , error in
        guard let data = data, error == nil else {
            Task {
                await completion(.failure(.badRequest))
            }
            return
        }
        guard let items = try? JSONDecoder().decode([Item].self, from: data) else {
            Task {
                await completion(.failure(.decodingError))
            }
            return
        }
        Task {
            await compltion(.success(items))
        }
    }.resume()
}

```

```swift

@MainActor
class ViewModel: ObservableObject {

    @Published var items: [Item] = []

    func populate(url: URL) async {
        Task.detached {
            print(Thread.isMainThread) // false
            // self.items = try await WebService().getAll(url: url) // Not possible
            await MainActor.run { // possible
                self.items = try await WebService().getAll(url: url)
            }
        }

    }

}

```
