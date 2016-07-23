import Foundation
import UIKit
import PlaygroundSupport

enum Currency: String {
    case eur = "EUR"
}

enum AccountType: String {
    case payment = "PAYMENT"
    case saving = "SAVING"
}

enum AccountResult {
    case succes([Account])
    case failure(ErrorProtocol)
}

enum APIError: ErrorProtocol {
    case emptyJSONData
    case invalidJSONData
    case invalidAccountNumber
    case invalidCurrency
    case invalidAccountType
}

struct Account {
    let accountBalanceInCents: Int
    let accountCurrency: Currency
    let accountId: Int
    let accountName: String
    let accountNumber: String
    let accountType: AccountType
    let alias: String
    let iban: String
    let linkedAccountId: Int?
    let productName: String?
    let productType: Int?
    let savingsTargetReached: Bool?
    let targetAmountInCents: Int?
}

struct AccountListsCoordinator {
    typealias accountCompletion = (accounts: [Account]) -> Void
    func fetchAccounts(@noescape completion: accountCompletion) throws {
        if let path = Bundle.main.urlForResource("accounts", withExtension: "json") {
            let accountResult = AccountListsCoordinator.accountsFromJSON(path: path) 
            switch accountResult {
            case .succes(let result):
                completion(accounts: result)
            case .failure(let error):
                throw(error)
            }
        }
    }
    
    static private func accountsFromJSON(path: URL) -> AccountResult {
        var accounts = [Account]()
        do {
            guard let jsonData = try String(contentsOf: path).data(using: .utf8)
                else { return .failure(APIError.emptyJSONData) }
            
            let jsonObject = try JSONSerialization.jsonObject(with: jsonData)
            
            for account in jsonObject["accounts"] as? [AnyObject] ?? [] {
                guard var 
                    accountBalanceInCents = account["accountBalanceInCents"] as? Int,
                    accountCurrency = account["accountCurrency"] as? String,
                    accountId = account["accountId"] as? Int,
                    accountName = account["accountName"] as? String,
                    accountType = account["accountType"] as? String,
                    alias = account["alias"] as? String,
                    iban = account["iban"] as? String,
                    linkedAccountId = account["linkedAccountId"] as? Int?,
                    productName = account["productName"] as? String?,
                    productType = account["productType"] as? Int?,
                    savingsTargetReached = account["savingsTargetReached"] as? Bool?,
                    targetAmountInCents = account["targetAmountInCents"] as? Int?
                    else { return .failure(APIError.invalidJSONData) }
                
                let accountNumber = account["accountNumber"]
                let formattedAccountNumber: String
                if let accountNumber = accountNumber as? String  {
                    formattedAccountNumber = accountNumber
                } else if let accountNumber = accountNumber as? Int {
                    formattedAccountNumber = String(accountNumber)
                } else {
                    return .failure(APIError.invalidAccountNumber)
                }
                
                guard let formatedAccountCurrency = Currency(rawValue: accountCurrency)
                    else { return .failure(APIError.invalidCurrency) }
                
                guard let formatedAccountType = AccountType(rawValue: accountType)
                    else { return .failure(APIError.invalidAccountType) }
                
                if accountName.unicodeScalars.count <= 1 {
                    accountName = "⚠️ Missing Name"
                }
                
                if iban.unicodeScalars.count <= 1 {
                    iban = "⚠️ Missing IBAN"
                }
                
                let account = Account(
                    accountBalanceInCents: accountBalanceInCents, 
                    accountCurrency: formatedAccountCurrency, 
                    accountId: accountId, 
                    accountName: accountName, 
                    accountNumber: formattedAccountNumber, 
                    accountType: formatedAccountType, 
                    alias: alias, 
                    iban: iban, 
                    linkedAccountId: linkedAccountId, 
                    productName: productName, 
                    productType: productType, 
                    savingsTargetReached: savingsTargetReached, 
                    targetAmountInCents: targetAmountInCents
                )
                accounts.append(account)
            }
            return .succes(accounts)
        }
        catch {
            return .failure(error)
        }
    }
}

protocol AccountListPresentable {
    func accountListDidUpdate(accounts: [Account]) 
}

struct AccountListPresenter {
    private let coordinator = AccountListsCoordinator()
    private let delegate: AccountListPresentable
    
    private(set) var accounts = [Account]() {
        didSet {
            delegate.accountListDidUpdate(accounts: accounts)
        }
    }
    
    init(delegate: AccountListPresentable) {
        self.delegate = delegate
        do { 
            try coordinator.fetchAccounts(completion: { (accounts) in
                self.accounts = accounts
            })
        }
        catch {
            fatalError("\(error)")
        }
    }
    
    func account(forIndex index: Int) -> Account {
        return accounts[index]
    }
}

enum AccountListTableStyle {
    case standard, icon
}
class AccountListTable: UITableViewController, AccountListPresentable {
    private let accountCellIdentifier = "accountCell"
    private var presenter: AccountListPresenter!
    private var style = AccountListTableStyle.standard
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override init(style: UITableViewStyle) {
        super.init(style: style)
        presenter = AccountListPresenter(delegate: self)
    }
    
    convenience init(style: AccountListTableStyle) {
        self.init(style: .grouped)
        self.style = style
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(CustomTableViewCell.self, forCellReuseIdentifier: accountCellIdentifier)
        tableView.allowsSelection = false
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return presenter.accounts.count
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 100
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: accountCellIdentifier, for: indexPath) as! CustomTableViewCell
        let account = presenter.account(forIndex: indexPath.row)
        
        switch style {
        case .standard:
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            cell.balance.text = formatter.string(from: account.accountBalanceInCents / 100) 
        case .icon:
            switch account.accountType {
            case .saving:
                cell.accountIcon.backgroundColor = UIColor.lightGray()  
            case .payment:
                cell.accountIcon.backgroundColor = UIColor.orange()  
            }
        }
        
        cell.accountName.text = account.accountName
        cell.iban.text = account.iban
        
        return cell
    }
    
    func accountListDidUpdate(accounts: [Account]) {
        //TODO: refresh
    }
}

class CustomTableViewCell: UITableViewCell {
    let accountIcon = UIImageView()
    let accountName = UILabel()
    let balance = UILabel()
    let iban = UILabel()
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: nil)
        
        accountIcon.translatesAutoresizingMaskIntoConstraints = false
        accountName.translatesAutoresizingMaskIntoConstraints = false
        balance.translatesAutoresizingMaskIntoConstraints = false
        iban.translatesAutoresizingMaskIntoConstraints = false
        
        accountIcon.layer.cornerRadius = 7
        
        accountName.font = UIFont.preferredFont(forTextStyle: UIFontTextStyleTitle1)
        balance.font = UIFont.preferredFont(forTextStyle: UIFontTextStyleTitle2)
        iban.font = UIFont.preferredFont(forTextStyle: UIFontTextStyleFootnote)
        
        contentView.addSubview(accountIcon)
        contentView.addSubview(accountName)
        contentView.addSubview(balance)
        contentView.addSubview(iban)
        
        let viewsDictionary = [
            "accountIcon" : accountIcon,
            "accountName" : accountName,
            "balance" : balance,
            "iban" : iban,
            ]
        
        contentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-[accountIcon(80)]", options: [], metrics: nil, views: viewsDictionary))
        contentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:[iban]-|", options: [], metrics: nil, views: viewsDictionary))
        contentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-[accountName]-[balance]-|", options: [], metrics: nil, views: viewsDictionary))
        contentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-[accountName]-[accountIcon(80)]-|", options: [], metrics: nil, views: viewsDictionary))
        contentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-[balance]-[iban]-|", options: [], metrics: nil, views: viewsDictionary))
    }
}

class TabBarController: UITabBarController {
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        //FIXME: improve image resolution
        let standardVC = AccountListTable(style: .standard)
        standardVC.tabBarItem = UITabBarItem(
            title: "Standard", 
            image: #imageLiteral(resourceName: "IMG_0090.PNG").withRenderingMode(.alwaysOriginal), 
            selectedImage: #imageLiteral(resourceName: "IMG_0089.PNG").withRenderingMode(.alwaysOriginal))
        
        let iconVC = AccountListTable(style: .icon)
        iconVC.tabBarItem = UITabBarItem(
            title: "Icon", 
            image: #imageLiteral(resourceName: "IMG_0092.PNG").withRenderingMode(.alwaysOriginal), 
            selectedImage: #imageLiteral(resourceName: "IMG_0091.PNG").withRenderingMode(.alwaysOriginal))
        
        self.viewControllers = [standardVC, iconVC]
    }
}


//MARK:- UI Setup
let tabBarController = TabBarController()
UITabBar.appearance().tintColor = UIColor.orange()
PlaygroundPage.current.liveView = tabBarController
