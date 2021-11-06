//
//  ViewController.swift
//  MyStocks
//
//  Created by  Pavel on 04.09.2021.
//

import UIKit

class ViewController: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate {
    
    // MARK: - Private properties
    private var companies: [String: String] = [:]
    private let urlTinkoff = "https://www.tinkoff.ru/invest/catalog/"
    private let urlCompanies = "https://cloud.iexapis.com/stable/stock/market/list/gainers?&token=pk_abaece40fce44a20876cc7da2d9013bd"
    
    // MARK: - IBOutlets
    @IBOutlet weak var companyNameLabel: UILabel!
    @IBOutlet weak var companySymbolLabel: UILabel!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var priceChangeLabel: UILabel!
    @IBOutlet weak var companyImage: UIImageView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var companyPickerView: UIPickerView!
    
    // MARK: - View lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        self.companyPickerView.dataSource = self
        self.companyPickerView.delegate = self
        self.activityIndicator.hidesWhenStopped = true
        self.fetchCompanies()
    }
    
    @IBAction func buyButton(_ sender: UIButton) {
        guard let url = URL(string: urlTinkoff) else { return }
        UIApplication.shared.open(url)
        UIPasteboard.general.string = companySymbolLabel.text
    }
    // MARK: - Private methods
    private func fetchCompanies() {
        self.activityIndicator.startAnimating()
        guard let url = URL(string: urlCompanies) else { return }
        let dataTask = URLSession.shared.dataTask(with: url) { (data, response, error) in
            guard error == nil,
                  (response as? HTTPURLResponse)?.statusCode == 200,
                  let data = data
            else {
                print("Network error!")
                DispatchQueue.main.async { self.showAlert() }
                return
            }
            do {
                guard let jsonObject = try JSONSerialization.jsonObject(with: data) as? [Any] else { return }
                for row in jsonObject {
                    guard let json = row as? [String:AnyObject],
                          let companyName = json["companyName"] as? String,
                          let companySymbol = json["symbol"] as? String
                    else { return }
                    self.companies[companyName] = companySymbol
                }
            } catch {
                print("JSON parsing error: " + error.localizedDescription)
            }
            DispatchQueue.main.async {
                self.companyPickerView.reloadAllComponents()
                self.requestQuoteUpdate()
            }
        }
        dataTask.resume()
    }
    
    private func requestQuote(for symbol: String) {
        guard let url = URL(string: "https://cloud.iexapis.com/stable/stock/\(symbol)/quote?&token=pk_abaece40fce44a20876cc7da2d9013bd") else { return }
        let dataTask = URLSession.shared.dataTask(with: url) { (data, response, error) in
            guard error == nil,
                  (response as? HTTPURLResponse)?.statusCode == 200,
                  let data = data
            else {
                print("Network error!")
                DispatchQueue.main.async { self.showAlert() }
                return
            }
            self.parseQuote(data: data)
        }
        dataTask.resume()
    }
    
    private func fetchImage(for symbol: String){
        guard let url = URL(string:"https://storage.googleapis.com/iex/api/logos/\(symbol).png") else { return }
        let dataTask = URLSession.shared.dataTask(with: url) {(data, response, error) in
            if let error = error {
                print(error.localizedDescription)
                DispatchQueue.main.async { self.showAlert() }
                return
            }
            DispatchQueue.main.async {
            if let data = data, let image = UIImage(data: data) {
                    self.companyImage.isHidden = false
                    self.companyImage.image = image
            } else {
                    self.companyImage.isHidden = true
                }
            }
        }
        dataTask.resume()
    }
    
    private func parseQuote(data: Data) {
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data)
            guard let json = jsonObject as? [String: Any],
                  let companyName = json["companyName"] as? String,
                  let companySymbol = json["symbol"] as? String,
                  let price = json["latestPrice"] as? Double,
                  let priceChange = json["change"] as? Double
            else {
                print("Invalid JSON format")
                return
            }
            DispatchQueue.main.async {
                self.displayStockInfo(companyName: companyName,
                                      symbol: companySymbol,
                                      price: price,
                                      priceChange: priceChange)
            }
        } catch {
            print("JSON parsing error: " + error.localizedDescription)
        }
    }
    
    private func displayStockInfo(companyName: String, symbol: String, price: Double, priceChange: Double){
        self.companyNameLabel.text = companyName
        self.companySymbolLabel.text = symbol
        self.priceLabel.text = "\(String(format:"%.2f", price))"
        self.priceChangeLabel.text = "\(String(format:"%.2f", priceChange))"
        if priceChange > 0 {
            self.priceChangeLabel.textColor = #colorLiteral(red: 0.3411764801, green: 0.6235294342, blue: 0.1686274558, alpha: 1)
        }
        if priceChange < 0 {
            self.priceChangeLabel.textColor = #colorLiteral(red: 0.9254902005, green: 0.2352941185, blue: 0.1019607857, alpha: 1)
        }
        self.activityIndicator.stopAnimating()
    }
    
    private func requestQuoteUpdate(){
        self.companyNameLabel.text = "—"
        self.companySymbolLabel.text = "—"
        self.priceLabel.text = "—"
        self.priceChangeLabel.text = "—"
        self.priceChangeLabel.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
        
        let selectedRow = self.companyPickerView.selectedRow(inComponent: 0)
        let selectedSymbol = Array(self.companies.values)[selectedRow]
        self.requestQuote(for: selectedSymbol)
        self.fetchImage(for: selectedSymbol)
    }
    
    private func showAlert() {
            let alert = UIAlertController(title: "Network error", message: "Please check your internet connection", preferredStyle: .alert)
            let cancelButton = UIAlertAction(title: "Try again", style: .cancel, handler: { action in self.fetchCompanies()}  )
            alert.addAction(cancelButton)
            self.present(alert, animated: true, completion: nil)
    }
    
    // MARK: - UIPickerViewDataSource
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return self.companies.keys.count
    }
    
    // MARK: - UIPickerViewDelegate
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return Array(self.companies.keys)[row]
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        self.activityIndicator.startAnimating()
        let selectedSymbol = Array(self.companies.values)[row]
        self.requestQuote(for: selectedSymbol)
        self.fetchImage(for: selectedSymbol)
    }
}

