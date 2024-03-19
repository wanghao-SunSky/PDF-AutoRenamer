//
//  PDFProcessor.swift
//  PDF-AutoRenamer
//
//  Created by mac on 2024/3/20.
//

import SwiftUI
import PDFKit
import AppKit

class PDFProcessor: ObservableObject {
    @Published var message: String = "Ready"

    func selectAndProcessPDF() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowedFileTypes = ["pdf"]

        let response = openPanel.runModal()
        if response == .OK, let originalURL = openPanel.url {
            self.message = "Extracting text..."
            guard let text = self.extractText(from: originalURL) else {
                self.message = "Failed to extract text from PDF."
                return
            }
            
            self.message = "Generating filename..."
            self.generateFilename(with: text) { suggestedFilename in
                DispatchQueue.main.async {
                    guard let newName = suggestedFilename else {
                        self.message = "Failed to generate a new filename."
                        return
                    }
                    
                    self.renamePDF(originalURL: originalURL, newName: newName)
                }
            }
        } else {
            self.message = "User cancelled or failed to select a PDF."
        }
    }
    
    private func extractText(from url: URL) -> String? {
        guard let pdfDocument = PDFDocument(url: url) else { return nil }
        return pdfDocument.string
    }
    
    func generateFilename(with text: String, completion: @escaping (String?) -> Void) {
        let apiKey = "YourAPiKey"
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!

        var request = URLRequest(url: url)
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpMethod = "POST"

        let json: [String: Any] = [
            "model": "gpt-3.5-turbo-0125",
            "messages": [
                ["role": "system", "content": "You are a helpful assistant. Look at the content provided and suggest a filename that accurately reflects the content. Use only the predominant language of the content (English or Chinese). The filename should only include letters, numbers, and underscores, and be no longer than 50 characters. Exclude any extensions like '.json' or '.txt'."],
                ["role": "user", "content": text]
            ]
        ]

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: json, options: [])
            request.httpBody = jsonData
        } catch {
            print("Error: Could not encode JSON")
            completion(nil)
            return
        }

        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error: \(error.localizedDescription)")
                completion(nil)
                return
            }

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("Error: Invalid response from the server.")
                completion(nil)
                return
            }

            guard let data = data else {
                print("Error: No data received from the server.")
                completion(nil)
                return
            }

            let jsonDecoder = JSONDecoder()
            do {
                let chatResponse = try jsonDecoder.decode(OpenAIChatResponse.self, from: data)
                if let initialFilename = chatResponse.choices.first?.message.content {
                    let filename = self.validateAndTrimFilename(initialFilename)
                    completion(filename)
                } else {
                    print("Error: Invalid data structure received.")
                    completion(nil)
                }
            } catch {
                print("Error: Could not decode JSON: \(error.localizedDescription)")
                completion(nil)
            }
        }.resume()
    }

    private func validateAndTrimFilename(_ initialFilename: String) -> String {
        let allowedChars = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_")
        let trimmedFilename = initialFilename.trimmingCharacters(in: allowedChars.inverted)
        return String(trimmedFilename.prefix(50))
    }


    struct OpenAIChatResponse: Codable {
        struct Choice: Codable {
            let message: Message
        }

        struct Message: Codable {
            let content: String
        }

        let choices: [Choice]
    }


    private func renamePDF(originalURL: URL, newName: String) {
        self.message = "Renaming and moving PDF..."
        guard let directoryURL = self.selectDirectory() else {
            self.message = "No directory selected."
            return
        }
        
        let newURL = directoryURL.appendingPathComponent(newName).appendingPathExtension("pdf")
        
        do {
            try FileManager.default.moveItem(at: originalURL, to: newURL)
            self.message = "PDF renamed and moved to: \(newURL)"
        } catch {
            self.message = "Failed to move PDF: \(error.localizedDescription)"
        }
    }
    
    private func selectDirectory() -> URL? {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.canCreateDirectories = false
        openPanel.allowsMultipleSelection = false
        openPanel.prompt = "Select Folder"
        
        let response = openPanel.runModal()
        return response == .OK ? openPanel.url : nil
    }
}
