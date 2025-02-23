local job = require("plenary.job")
local Config = require("chatgpt.config")
local logger = require("chatgpt.common.logger")
local Utils = require("chatgpt.utils")

local Api = {}

function Api.completions(custom_params, cb)
  local openai_params = Utils.collapsed_openai_params(Config.options.openai_params)
  local params = vim.tbl_extend("keep", custom_params, openai_params)
  Api.make_call(Api.COMPLETIONS_URL, params, cb)
end

function Api.chat_completions(custom_params, cb, should_stop)
  local openai_params = Utils.collapsed_openai_params(Config.options.openai_params)
  local params = vim.tbl_extend("keep", custom_params, openai_params)
  -- the custom params contains <dynamic> if model is not constant but function
  -- therefore, use collapsed openai params (with function evaluated to get model) if that is the case
  local raw_chunks = ""
  local state = "START"

  cb = vim.schedule_wrap(cb)

  local extra_curl_params = Config.options.extra_curl_params
  local args = {
    Api.OPENAI_API_HOST.."/infer",
    "-H", "accept: */*",
    "-H", "accept-language: en-US,en;q=0.9",
    "-H", "Content-Type: application/json",
    "-H", "user-agent: " ..Api.USER_AGENT,
    -- "-d", vim.json.encode(params),
    "--data-raw", '{"question":"what are the latest advancements in Java?","options":{"date":"03/07/2024","language":"en-US","detailed":true,"anonUserId":"k1sl6bq45o285wmikabg8bff","answerModel":"Phind Instant","searchMode":"auto","allowMultiSearch":false,"customLinks":[]},"context":"","backend_token":"qrLQuyEMJVQXPzhf3dGu+0QOfI8oMjOtvSJ5QysHPe38mjTU69Nb8ZnNqdLB3Iyk4p1WnFEqPg==","challenge":-0.692499201726473}'
  }

  if extra_curl_params ~= nil then
    for _, param in ipairs(extra_curl_params) do
      table.insert(args, param)
    end
  end

  Api.exec(
    "curl",
    args,
    function(chunk)
      local ok, json = pcall(vim.json.decode, chunk)
      if ok and json ~= nil then
        if json.error ~= nil then
          cb(json.error.message, "ERROR")
          return
        end
      end
      for line in chunk:gmatch("[^\n]+") do
        local phind_tag = string.gsub(line, "^data: ", "")
        if phind_tag then
          if string.find(line, 'PHIND_DONE') then
            cb(raw_chunks, "END")
          end
          local raw_json = string.match(phind_tag, ">".."(.-)".."<")
          if raw_json then
            ok, json = pcall(vim.json.decode, raw_json, {
              luanil = {
                object = true,
                array = true,
              },
            })
            if ok and json ~= nil then
              -- this will be the metadata returned from the phind api
            end
          else
            -- this will be the actual answer!
            cb(raw_json, state)
          end
        end
      end
    end,
    function(err, _)
      cb(err, "ERROR")
    end,
    should_stop,
    function()
      cb(raw_chunks, "END")
    end
  )
end

function Api.edits(custom_params, cb)
  local openai_params = Utils.collapsed_openai_params(Config.options.openai_params)
  local params = vim.tbl_extend("keep", custom_params, openai_params)
  if params.model == "text-davinci-edit-001" or params.model == "code-davinci-edit-001" then
    vim.notify("Edit models are deprecated", vim.log.levels.WARN)
    Api.make_call(Api.EDITS_URL, params, cb)
    return
  end

  Api.make_call(Api.CHAT_COMPLETIONS_URL, params, cb)
end

function Api.make_call(url, params, cb)
  TMP_MSG_FILENAME = os.tmpname()
  --[[local f = io.open(TMP_MSG_FILENAME, "w+")
  if f == nil then
    vim.notify("Cannot open temporary message file: " .. TMP_MSG_FILENAME, vim.log.levels.ERROR)
    return
  end
  f:write(vim.fn.json_encode(params))
  f:close() ]]

  local state = "START"

  local args = {
    url,
    "-H", "accept */*",
    "-H", "accept-language: en-US,en;q=0.9",
    "-H", "Content-Type: application/json",
    "-H", "user-agent: " ..Api.USER_AGENT,
    --"-d", "@" .. TMP_MSG_FILENAME,
    "--data-raw", '{"question":"what are the latest advancements in Java?","options":{"date":"03/07/2024","language":"en-US","detailed":true,"anonUserId":"k1sl6bq45o285wmikabg8bff","answerModel":"Phind Instant","searchMode":"auto","allowMultiSearch":false,"customLinks":[]},"context":"","backend_token":"qrLQuyEMJVQXPzhf3dGu+0QOfI8oMjOtvSJ5QysHPe38mjTU69Nb8ZnNqdLB3Iyk4p1WnFEqPg==","challenge":-0.692499201726473}'
  }
  print(vim.inspect(args))

  local extra_curl_params = Config.options.extra_curl_params
  if extra_curl_params ~= nil then
    for _, param in ipairs(extra_curl_params) do
      table.insert(args, param)
    end
  end

  local raw_chunks = ""

  --[[ Api.job = job
    :new({
      command = "curl",
      args = args,
      on_exit = vim.schedule_wrap(function(response, exit_code)
        Api.handle_response(response, exit_code, cb)
      end),
    })
    :start() ]]
  Api.exec(
    "curl",
    args,
    function(chunk)
      local ok, json = pcall(vim.json.decode, chunk)
      if ok and json ~= nil then
        if json.error ~= nil then
          cb(json.error.message, "ERROR")
          return
        end
      end
      for line in chunk:gmatch("[^\n]+") do
        local phind_tag = string.gsub(line, "^data: ", "")
        if phind_tag then
          if string.find(line, 'PHIND_DONE') then
            cb(raw_chunks, "END")
          end
          local raw_json = string.match(phind_tag, ">".."(.-)".."<")
          if raw_json then
            ok, json = pcall(vim.json.decode, raw_json, {
              luanil = {
                object = true,
                array = true,
              },
            })
            if ok and json ~= nil then
              -- this will be the metadata returned from the phind api
            end
          else
            -- this will be the actual answer!
            cb(raw_json, state)
          end
        end
      end
    end,
    function(err, _)
      cb(err, "ERROR")
    end,
    --should_stop,
    function()
      cb(raw_chunks, "END")
    end
  )
end

Api.handle_response = vim.schedule_wrap(function(response, exit_code, cb)
  os.remove(TMP_MSG_FILENAME)
  if exit_code ~= 0 then
    vim.notify("An Error Occurred ...", vim.log.levels.ERROR)
    cb("ERROR: API Error")
  end

  local result = table.concat(response:result(), "\n")
  local json = vim.fn.json_decode(result)
  if json == nil then
    cb("No Response.")
  elseif json.error then
    cb("// API ERROR: " .. json.error.message)
  else
    local message = json.choices[1].message
    if message ~= nil then
      local message_response
      local first_message = json.choices[1].message
      if first_message.function_call then
        message_response = vim.fn.json_decode(first_message.function_call.arguments)
      else
        message_response = first_message.content
      end
      if (type(message_response) == "string" and message_response ~= "") or type(message_response) == "table" then
        cb(message_response, json.usage)
      else
        cb("...")
      end
    else
      local response_text = json.choices[1].text
      if type(response_text) == "string" and response_text ~= "" then
        cb(response_text, json.usage)
      else
        cb("...")
      end
    end
  end
end)

function Api.close()
  if Api.job then
    job:shutdown()
  end
end

local function loadConfigFromEnv(envName, configName, callback)
  local variable = os.getenv(envName)
  if not variable then
    return
  end
  local value = variable:gsub("%s+$", "")
  Api[configName] = value
  if callback then
    callback(value)
  end
end


function Api.setup()
  Api.OPENAI_API_HOST = 'https://https.api.phind.com'
  Api.OPENAI_API_KEY = ""
  --Api.AUTHORIZATION_HEADER = "api-key: " .. Api.OPENAI_API_KEY
  Api.AUTHORIZATION_HEADER = ""
  Api.USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36'"
  -- phind requires backend_token and for some requests, the __Secure-next-auth.session-token cookie
end

function Api.exec(cmd, args, on_stdout_chunk, on_complete, should_stop, on_stop)
  local stdout = vim.loop.new_pipe()
  local stderr = vim.loop.new_pipe()
  local stderr_chunks = {}

  local handle, err
  local function on_stdout_read(_, chunk)
    if chunk then
      vim.schedule(function()
        if should_stop and should_stop() then
          if handle ~= nil then
            handle:kill(2) -- send SIGINT
            stdout:close()
            stderr:close()
            handle:close()
            on_stop()
          end
          return
        end
        on_stdout_chunk(chunk)
      end)
    end
  end

  local function on_stderr_read(_, chunk)
    if chunk then
      table.insert(stderr_chunks, chunk)
    end
  end

  handle, err = vim.loop.spawn(cmd, {
    args = args,
    stdio = { nil, stdout, stderr },
  }, function(code)
    stdout:close()
    stderr:close()
    if handle ~= nil then
      handle:close()
    end

    vim.schedule(function()
      if code ~= 0 then
        on_complete(vim.trim(table.concat(stderr_chunks, "")))
      end
    end)
  end)

  if not handle then
    on_complete(cmd .. " could not be started: " .. err)
  else
    stdout:read_start(on_stdout_read)
    stderr:read_start(on_stderr_read)
  end
end

return Api
