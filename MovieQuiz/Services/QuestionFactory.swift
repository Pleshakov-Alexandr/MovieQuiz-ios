//
//  QuestionFactory.swift
//  MovieQuiz
//
//  Created by Александр Плешаков on 11.12.2023.
//

import Foundation
import UIKit

final class QuestionFactory: QuestionFactoryProtocol {
    private let moviesLoader: MoviesLoading
    private weak var delegate: QuestionFactoryDelegate?
    private var movies: [MostPopularMovie] = []
    
    init(moviesLoader: MoviesLoading, delegate: QuestionFactoryDelegate?) {
        self.moviesLoader = moviesLoader
        self.delegate = delegate
    }
    
    func moviesIsEmpty() -> Bool {
        return movies.isEmpty
    }
    
    func loadData() {
        moviesLoader.loadMovies { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
                case .success(let mostPopularMovies):
                    self.movies = mostPopularMovies.items // сохраняем фильм в нашу новую переменную
                    self.delegate?.didLoadDataFromServer() // сообщаем, что данные загрузились
                case .failure(let error):
                    self.delegate?.didFailToLoadData(with: error) // сообщаем об ошибке нашему MovieQuizViewController
                }
            }
        }
    }
    
    func requestNextQuestion() {
        DispatchQueue.global().async { [weak self] in
            guard let self = self else { return }
            let index = (0..<self.movies.count).randomElement() ?? 0
            
            guard let movie = self.movies[safe: index] else { return }
            
            var imageData = Data()

            do {
                imageData = try Data(contentsOf: movie.imageURL)
            } catch {
                print("Failed to load image")
                DispatchQueue.main.async {
                    let model = AlertModel(title: "Ошибка загрузки",
                                           message: "Невозможно загрузить постер",
                                           buttonText: "Начать тест заново") { [weak self] _ in
                        guard let self = self else { return }
                        self.loadData()
                    }
                    let alert = AlertPresenter(delegate: self.delegate as? UIViewController)
                    alert.showAlert(model: model)
                    return
                }
            }
            
            let rating = Float(movie.rating) ?? 0
            let isLess = Bool.random()
            let lessOrGreaterText = isLess ? "меньше" : "больше или равен"
            let text = "Рейтинг этого фильма \(lessOrGreaterText) чем \(Int(round(Float(movie.rating) ?? 7)))?"
            let correctAnswer = isLess ? rating < round(Float(movie.rating) ?? 7) : rating >= round(Float(movie.rating) ?? 7)
            
            let question = QuizQuestion(image: imageData,
                                         text: text,
                                         correctAnswer: correctAnswer)
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.didReceiveNextQuestion(question: question)
            }
        }
    }
}
