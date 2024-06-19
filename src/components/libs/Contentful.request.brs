' @import /components/libs/ContentfulResponse.brs

sub init()
  m._ERROR_CODE = 400
  m._HTTP_REQUEST_COMPLETED = 1
  m._REDIRECTION_CODE = 300
  m._SUCCESS_CODE = 200

  m._port = CreateObject("roMessagePort")
  m._urlTransfer = CreateObject("roUrlTransfer")

  m.top.functionName = "sendContentfulRequest"
end sub

sub sendContentfulRequest()
  options = _prepareOptions()

  _sendRequest(options)
  _waitForResponse()
end sub

function _prepareOptions()
  options = {
    headers: { "Authorization": "Bearer " + m.top.accessToken },
    method: UCase(m.top.method),
    url: [m.top.baseUrl, m.top.path].join("/"),
  }

  options.headers.append(m.top.headers)

  if (m.top.body <> Invalid) then options.body = m.top.body
  if (m.top.queryParams <> Invalid) then options.url += _parseQueryParams(m.top.queryParams)

  return options
end function

sub _sendRequest(options as Object)
  m._urlTransfer.setUrl(options.url)
  m._urlTransfer.setRequest(options.method)

  for each headerKey in options.headers
    m._urlTransfer.addHeader(headerKey, options.headers[headerKey])
  end for

  m._urlTransfer.enableEncodings(true)
  m._urlTransfer.enablePeerVerification(false)
  m._urlTransfer.retainBodyOnError(true)
  m._urlTransfer.setMessagePort(m._port)

  if (options.method = "GET")
    m._urlTransfer.asyncGetToString()
  else if (options.method = "POST")
    body = ""
    if (options.body <> Invalid) then body = FormatJSON(options.body)

    m._urlTransfer.asyncPostFromString(body)
  end if
end sub

sub _waitForResponse()
  message = Wait(m.top.timeout, m._port)

  if (Type(message) = "roUrlEvent")
    _handleResponse(message)
  else
    _handleTimeout()
  end if
end sub

sub _handleResponse(message as Object)
  if (message.getInt() = m._HTTP_REQUEST_COMPLETED)
    responseCode = message.getResponseCode()

    if (responseCode >= m._SUCCESS_CODE AND responseCode < m._ERROR_CODE)
      m.top.result = { id: m.top.id, data: _parseResponse(message.getString()), statusCode: responseCode }
    else
      m.top.result = { id: m.top.id, error: message.getFailureReason(), statusCode: responseCode }
    end if
  end if
end sub

function _parseResponse(responseString as String) as Dynamic
  try
    return ContentfulResponse(responseString).parse({
      itemEntryPoints: m.top.itemEntryPoints,
      removeUnresolved: m.top.removeUnresolved,
    })
  catch _error
    return responseString
  end try
end function

sub _handleTimeout()
  m._urlTransfer.asyncCancel()

  m.top.result = { id: m.top.id }
end sub

function _parseQueryParams(queryParams as Object) as String
  query = ""

  for each queryParamKey in queryParams
    if (query = "")
      query += "?"
    else
      query += "&"
    end if

    query += [queryParamKey.toStr(), queryParams[queryParamKey].toStr()].join("=")
  end for

  return query
end function
