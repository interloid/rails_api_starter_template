module RequestHelpers
  def json_body = JSON.parse(response.body)

  def post_json(path, params: {}, headers: {})
    post path, params: params.to_json, headers: headers.merge("Content-Type" => "application/json")
  end
end

RSpec.configure { |c| c.include RequestHelpers, type: :request }
