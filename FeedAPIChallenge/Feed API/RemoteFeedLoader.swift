//
//  Copyright © 2018 Essential Developer. All rights reserved.
//

import Foundation

public final class RemoteFeedLoader: FeedLoader {
	//MARK: - Public

	public enum Error: Swift.Error {
		case connectivity
		case invalidData
	}

	public init(url: URL, client: HTTPClient) {
		self.url = url
		self.client = client
	}

	public func load(completion: @escaping (FeedLoader.Result) -> Void) {
		client.get(from: url) { [weak self] httpClientResult in
			guard self != nil else { return }

			let result: FeedLoader.Result = Self.dataResult(from: httpClientResult)
				.flatMap(RemoteFeedLoader.feedLoaderResult)
			completion(result)
		}
	}

	//MARK: - Private

	private typealias DataResult = Swift.Result<Data, Swift.Error>

	private struct ResponseRootEntity: Decodable {
		let items: [RemoteFeedImage]
	}

	private struct RemoteFeedImage: Decodable {
		let id: UUID
		let description: String?
		let location: String?
		let url: URL

		var feedImage: FeedImage {
			return .init(id: id, description: description, location: location, url: url)
		}

		enum CodingKeys: String, CodingKey {
			case id = "image_id"
			case description = "image_desc"
			case location = "image_loc"
			case url = "image_url"
		}
	}

	private let url: URL
	private let client: HTTPClient

	private static func dataResult(from httpClientResult: HTTPClient.Result) -> DataResult {
		return httpClientResult.mapError { _ in Error.connectivity }
			.flatMap { (responseData, httpResponse) -> DataResult in
				guard httpResponse.isStatusOK else {
					return .failure(Error.invalidData)
				}
				return .success(responseData)
			}
	}

	private static func feedLoaderResult(from responseData: Data) -> FeedLoader.Result {
		guard let remoteFeedImages = try? JSONDecoder().decode(ResponseRootEntity.self, from: responseData) else {
			return .failure(Error.invalidData)
		}

		let feedImages = remoteFeedImages.items.map { $0.feedImage }
		return .success(feedImages)
	}
}

//MARK: - HTTPURLResponse extension

//NOTE: It would be better to share the extension below or at least move into separate file,
//but due to restrictions specified in the task it's not allowed to add/change other files
private extension HTTPURLResponse {
	private static var OK_200: Int { return 200 }

	var isStatusOK: Bool {
		return statusCode == HTTPURLResponse.OK_200
	}
}
