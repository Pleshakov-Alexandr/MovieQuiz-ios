//
//  MovieQuizPresenter.swift
//  MovieQuiz
//
//  Created by Александр Плешаков on 16.01.2024.
//

import UIKit


final class MovieQuizPresenter: QuestionFactoryDelegate {
    
    // MARK: Properties
    
    private weak var viewController: MovieQuizViewControllerProtocol?
    private let questionsAmount = 10
    
    private var currentQuestionIndex = 0
    private var correctAnswers = 0
    
    private var currentQuestion: QuizQuestion?
    private var questionFactory: QuestionFactory?
    private var resultAlert: AlertPresenter?
    private var statisticService: StatisticService?
    
    // MARK: Init
    
    init(viewController: MovieQuizViewControllerProtocol) {
        self.viewController = viewController
        
        statisticService = StatisticServiceImplementation()
        
        questionFactory = QuestionFactory(moviesLoader: MoviesLoader(networkClient: NetworkClient()), delegate: self)
        questionFactory?.loadData()
        viewController.showLoadingIndicator()
    }

    
    // MARK: QuestionFactoryDelegate
    
    func didReceiveNextQuestion(question: QuizQuestion?) {
        guard let question = question else {
            return
        }
        currentQuestion = question
        let viewModel = convert(model: question)
        
        DispatchQueue.main.async { [weak self] in
            self?.viewController?.show(quiz: viewModel)
        }
        viewController?.hideLoadingIndicator()
        viewController?.changeButtonState(isEnabled: true)
    }
    
    func didLoadDataFromServer() {
        viewController?.hideLoadingIndicator()
        if (questionFactory?.moviesIsEmpty() ?? true) {
            let model = AlertModel(title: "Ошибка загрузки",
                                   message: "Проблемы с API key\nПопробуйте позже",
                                   buttonText: "Ok") { [weak self] _ in
                self?.questionFactory?.loadData()
            }
            
            let alert = AlertPresenter(delegate: viewController as? MovieQuizViewController)
            viewController?.showLoadingIndicator()
            alert.showAlert(model: model)
            return
        }
        questionFactory?.requestNextQuestion()
    }
    
    func didFailToLoadData(with error: Error) {
        viewController?.showNetworkError(message: error.localizedDescription)
    }
    
    // MARK: Internal Functions
    
    func restartGame() {
        currentQuestionIndex = 0
        correctAnswers = 0
        questionFactory?.requestNextQuestion()
    }
    
    func buttonYesClicked() {
        didAnswer(isYes: true)
    }
    
    func buttonNoClicked() {
        didAnswer(isYes: false)
    }
    
    // MARK: Private Functions
    
    private func didAnswer(isCorrect: Bool) {
        if isCorrect {
            correctAnswers += 1
        }
    }
    
    func convert(model: QuizQuestion) -> QuizStepViewModel {
        let questionStep = QuizStepViewModel(image: UIImage(data: model.image) ?? UIImage(),
            question: model.text,
            questionNumber: "\(currentQuestionIndex + 1)/\(questionsAmount)")
        
        return questionStep
    }
    
    private func isLastQuestion() -> Bool {
        currentQuestionIndex == questionsAmount - 1
    }
    
    private func resetQuestionIndex() {
        currentQuestionIndex = 0
    }
    
    private func switchToNextQuestion() {
        currentQuestionIndex += 1
    }
    
    private func proceedToNextQuestionOrResults() {
        if isLastQuestion() {
            guard let statisticService = statisticService else {
                print("statisticService = nil")
                return
            }
            
            statisticService.store(correct: correctAnswers, total: questionsAmount)
            
            let text = """
                Ваш результат: \(correctAnswers)/\(questionsAmount)
                Количество сыгранных квизов:  \(statisticService.gamesCount)
                Рекорд: \(statisticService.bestGame.correct)/\(statisticService.bestGame.total) (\(statisticService.bestGame.date.dateTimeString))
                Средняя точность: \(String(format: "%.2f", statisticService.totalAccuracy))%
                """
            
            let viewModel = AlertModel(title: "Этот раунд окончен", message: text, buttonText: "Сыграть еще раз") { [weak self] _ in
                guard let self = self else { return }
                viewController?.showLoadingIndicator()
                restartGame()
            }
            resultAlert = AlertPresenter(delegate: viewController as? MovieQuizViewController)
            resultAlert?.showAlert(model: viewModel)
        } else {
            switchToNextQuestion()
            viewController?.showLoadingIndicator()
            questionFactory?.requestNextQuestion()
        }
    }
    
    private func proceedWithAnswer(isCorrect: Bool) {
        viewController?.changeButtonState(isEnabled: false)
        
        didAnswer(isCorrect: isCorrect)
        viewController?.decoratePosterImage(isCorrect: isCorrect)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self = self else { return }
            viewController?.showLoadingIndicator()
            proceedToNextQuestionOrResults()
        }
    }
    
    private func didAnswer(isYes: Bool) {
        guard let currentQuestion = currentQuestion else {
            return
        }
        let givenAnswer = isYes
        
        proceedWithAnswer(isCorrect: givenAnswer == currentQuestion.correctAnswer)
    }
    
}
