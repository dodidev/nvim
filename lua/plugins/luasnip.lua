return {
  "L3MON4D3/LuaSnip",
  event = "InsertEnter",
  opts = function(_, opts)
    local ls = require("luasnip")
    local s = ls.snippet
    local t = ls.text_node
    local i = ls.insert_node
    local f = ls.function_node

    local function get_comment_parts()
      local cs = vim.bo.commentstring
      if type(cs) ~= "string" or cs == "" then
        return "#", ""
      end

      local left, right = cs:match("^(.*)%%s(.*)$")
      if not left then
        return vim.trim(cs), ""
      end

      left = vim.trim(left or "")
      right = vim.trim(right or "")
      if left == "" then
        left = "#"
      end
      return left, right
    end

    local function comment_prefix(tag)
      local left = get_comment_parts()
      return left .. " " .. tag .. ": "
    end

    local function comment_suffix()
      local _, right = get_comment_parts()
      return right ~= "" and (" " .. right) or ""
    end

    local function section_prefix(label)
      local left = get_comment_parts()
      return left .. " -- " .. label .. ": "
    end

    local function section_tail(label, name)
      local left, right = get_comment_parts()
      local max_width = vim.bo.textwidth == 0 and 80 or vim.bo.textwidth
      local title = vim.trim(name or "")

      if title == "" then
        title = "Section"
      end

      local head = left .. " -- " .. label .. ": " .. title .. " "
      local tail_width = right ~= "" and (vim.fn.strdisplaywidth(right) + 1) or 0
      local remaining = max_width - vim.fn.strdisplaywidth(head) - tail_width
      local tail = remaining > 0 and string.rep("-", remaining) or ""

      if right ~= "" then
        return " " .. tail .. " " .. right
      end

      return " " .. tail
    end

    local function header_rule()
      local left, right = get_comment_parts()
      local max_width = vim.bo.textwidth == 0 and 80 or vim.bo.textwidth
      local tail_width = right ~= "" and (vim.fn.strdisplaywidth(right) + 1) or 0
      local remaining = max_width - vim.fn.strdisplaywidth(left .. " ") - tail_width
      local rule = string.rep("-", math.max(3, remaining))

      if right ~= "" then
        return left .. " " .. rule .. " " .. right
      end

      return left .. " " .. rule
    end

    local function header_title_prefix()
      local left = get_comment_parts()
      return left .. " "
    end

    local function header_title_suffix()
      local _, right = get_comment_parts()
      return right ~= "" and (" " .. right) or ""
    end

    local function get_debug_parts()
      local filetype = vim.bo.filetype
      local map = {
        lua = { 'vim.print("DBG:", ', ")" },
        python = { 'print("DBG:", ', ")" },
        javascript = { 'console.log("DBG:", ', ");" },
        typescript = { 'console.log("DBG:", ', ");" },
        javascriptreact = { 'console.log("DBG:", ', ");" },
        typescriptreact = { 'console.log("DBG:", ', ");" },
        go = { 'fmt.Println("DBG:", ', ")" },
        rust = { 'println!("DBG: {:?}", ', ");" },
        dart = { 'print("DBG: ${', '}");' },
      }
      return unpack(map[filetype] or { 'print("DBG:", ', ")" })
    end

    ls.add_snippets("all", {
      s("endesh", {
        t("–"),
      }),
      s("emdash", {
        t("—"),
      }),
      s("pbar", {
        f(function()
          return section_prefix("SECTION")
        end, {}),
        i(1, "Section Name"),
        f(function(args)
          return section_tail("SECTION", args[1][1])
        end, { 1 }),
      }),
      s("secstart", {
        f(function()
          return section_prefix("SECTION START")
        end, {}),
        i(1, "Section Name"),
        f(function(args)
          return section_tail("SECTION START", args[1][1])
        end, { 1 }),
      }),
      s("secend", {
        f(function()
          return section_prefix("SECTION END")
        end, {}),
        i(1, "Section Name"),
        f(function(args)
          return section_tail("SECTION END", args[1][1])
        end, { 1 }),
      }),
      s("header", {
        f(header_rule, {}),
        t({ "", "" }),
        f(header_title_prefix, {}),
        i(1, "Header Name"),
        f(header_title_suffix, {}),
        t({ "", "" }),
        f(header_rule, {}),
      }),
      s("todo", {
        f(function()
          return comment_prefix("TODO")
        end, {}),
        i(1, "task"),
        f(comment_suffix, {}),
      }),
      s("fixme", {
        f(function()
          return comment_prefix("FIXME")
        end, {}),
        i(1, "bug"),
        f(comment_suffix, {}),
      }),
      s("note", {
        f(function()
          return comment_prefix("NOTE")
        end, {}),
        i(1, "context"),
        f(comment_suffix, {}),
      }),
      s("hack", {
        f(function()
          return comment_prefix("HACK")
        end, {}),
        i(1, "temporary workaround"),
        f(comment_suffix, {}),
      }),
      s("dbg", {
        f(function()
          local prefix = get_debug_parts()
          return prefix
        end, {}),
        i(1, "value"),
        f(function()
          local _, suffix = get_debug_parts()
          return suffix
        end, {}),
      }),
      s("tsnow", {
        f(function()
          local left, right = get_comment_parts()
          local stamp = os.date("%Y-%m-%d %H:%M:%S")
          return right ~= "" and (left .. " " .. stamp .. " " .. right) or (left .. " " .. stamp)
        end, {}),
      }),
    }, { key = "user-pbar-snippet" })

    ls.add_snippets("lua", {
      s("req", { t("local "), i(1, "mod"), t(' = require("'), i(2, "module"), t('")') }),
      s("lfn", {
        t("local function "),
        i(1, "name"),
        t("("),
        i(2),
        t({ ")", "  " }),
        i(0),
        t({ "", "end" }),
      }),
    }, { key = "user-lua-helper-snippets" })

    ls.add_snippets("dart", {
      s("stless", {
        t({ "class " }),
        i(1, "WidgetName"),
        t({ " extends StatelessWidget {", "  const " }),
        f(function(args)
          return args[1][1]
        end, { 1 }),
        t({ "({super.key});", "", "  @override", "  Widget build(BuildContext context) {", "    return " }),
        i(0, "const SizedBox.shrink()"),
        t({ ";", "  }", "}" }),
      }),
    }, { key = "user-dart-helper-snippets" })

    return opts
  end,
}
