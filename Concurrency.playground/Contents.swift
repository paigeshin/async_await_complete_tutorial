import UIKit

actor BankAccount {
    
    let accountNumber: Int
    var balance: Double
    
    init(accountNumber: Int, balance: Double) {
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
