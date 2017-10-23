defmodule Bitmex.Rest.HTTPClient do
  use HTTPoison.Base
  import Bitmex.URI, only: [encode_query: 1]

  @api_key Application.get_env(:bitmex, :api_key)
  @api_secret Application.get_env(:bitmex, :api_secret)
  @test_mode Application.get_env(:bitmex, :test_mode)
  @api_host "https://www.bitmex.com"
  @api_testnet_host "https://testnet.bitmex.com"
  @api_path "/api/v1"
  @api_uri (@test_mode && @api_testnet_host || @api_host) <> @api_path

  def non_auth_get(uri, params \\ []) do
    uri |> uri_with_query(params) |> get
  end

  def auth_get(uri, params \\ []) do
    query = uri_with_query(uri, params)
    get(query, auth_headers(:get, query))
  end

  def auth_post(uri, params) do
    auth_request(:post, uri, params)
  end

  def auth_put(uri, params) do
    auth_request(:put, uri, params)
  end

  def auth_delete(uri, params) do
    auth_request(:delete, uri, params)
  end

  def auth_request(verb, uri, params, via \\ :json)

  def auth_request(verb, uri, params, :url_encoding) do
    body = encode_query(params)
    headers = verb |> auth_headers(uri, body) |> put_content_type(:params)
    request(verb, uri, body, headers, [])
  end

  def auth_request(verb, uri, params, :json) do
    body = Poison.encode!(params)
    headers = verb |> auth_headers(uri, body) |> put_content_type(:json)
    request(verb, uri, body, headers, [])
  end

  defp put_content_type(headers, :params) do
    Keyword.put(headers, :"Content-Type", "application/x-www-form-urlencoded")
  end

  defp put_content_type(headers, :json) do
    Keyword.put(headers, :"Content-Type", "application/json")
  end

  def uri_with_query(uri, []), do: uri
  def uri_with_query(uri, map) when is_map(map) and map_size(map) == 0, do: uri
  def uri_with_query(uri, params), do: "#{uri}?#{encode_query(params)}"

  ## Helpers

  defp auth_headers(verb, encoded_uri, data \\ "") do
    verb_string = to_verb_string(verb)
    nonce = Bitmex.Auth.nonce()
    sig = Bitmex.Auth.sign(@api_secret, verb_string, @api_path <> encoded_uri,
                           nonce, data)
    ["api-nonce": to_string(nonce), "api-key": @api_key, "api-signature": sig]
  end

  defp to_verb_string(verb) do
    verb |> to_string |> String.upcase
  end

  ## HTTPoison callbacks

  def process_url(url), do: @api_uri <> url

  def process_response_body(body), do: Poison.decode!(body)

  def process_request_headers(headers) do
    Keyword.merge(headers, ["Accept": "application/json",
                            "X-Requested-With": "XMLHttpRequest"])
  end
end
