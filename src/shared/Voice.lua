-- The machine voice (design/gdd/cybernetics.md §6). Owner, 2026-10-28, on going 100% metal: "you lose your
-- humanity, you no longer speak the way you did." A fully converted conduit's chat comes out flattened:
--   * all capitals, every sentence ends in a full stop: no ! or ?, no ~, no ...
--   * contractions spelled out (DON'T -> DO NOT, I'M -> I AM)
--   * no laughter (lol, lmao, haha), no emoticons (:) :D), no emoji, no stretched words (sooooo -> SO)
-- Pure text in, text out, so every client renders the same line (client/Speech.lua) and smoke can test it.
-- The input is chat text as TextChatService hands it over: already filtered and rich-text escaped, so
-- entities (&lt; &amp; ...) are left untouched and the result is still safe rich text.
local Voice = {}

Voice.Silent = "..." -- what comes out when nothing human was left to say

-- whole words first, so CAN'T doesn't become CA NOT
local WORDS = {
	{ "CAN'T", "CANNOT" }, { "WON'T", "WILL NOT" }, { "AIN'T", "IS NOT" }, { "I'M", "I AM" },
	{ "LET'S", "LET US" }, { "Y'ALL", "YOU ALL" },
}
local ENDINGS = { { "N'T", " NOT" }, { "'RE", " ARE" }, { "'LL", " WILL" }, { "'VE", " HAVE" }, { "'D", " WOULD" } }

local function laughter(word)
	local w = word:gsub("[^%a]", "")
	return w == "LOL" or w == "LMAO" or w == "LMFAO" or w == "ROFL" or w == "XD" or w == "KEK"
		or w:match("^L+O+L+$") ~= nil or w:match("^LMA+O+$") ~= nil
		or (#w >= 4 and w:match("^[HAE]+$") ~= nil and w:sub(1, 1) == "H")
end

-- sooooo -> SO: a letter three or more times in a row is one letter; "cool" and "all" keep their pairs
local function unstretch(word)
	local out, i = {}, 1
	while i <= #word do
		local c, j = word:sub(i, i), i
		while word:sub(j + 1, j + 1) == c do
			j += 1
		end
		table.insert(out, if j - i + 1 >= 3 then c else word:sub(i, j))
		i = j + 1
	end
	return table.concat(out)
end

local function flatten(s)
	s = " " .. string.upper(s) .. " " -- padded so the word edges (%f) work at both ends
	s = s:gsub("[\240-\244][\128-\191]*", "") -- emoji (4-byte UTF-8)
	s = s:gsub("%f[^%s][:;=]%-?[%)%(DPOS/\\|%]%[]+%f[%s]", "") -- :) ;D =P :-( as whole words only
	for _, pair in WORDS do
		s = s:gsub("%f[%a]" .. pair[1] .. "%f[%A]", pair[2])
	end
	for _, pair in ENDINGS do
		s = s:gsub("(%a)" .. pair[1] .. "%f[%A]", "%1" .. pair[2])
	end
	s = s:gsub("%a+", unstretch)
	s = s:gsub("[!?]+", ". "):gsub("~", "")
	s = s:gsub("%.%.+", ". ") -- an ellipsis is one stop (3.5 stays 3.5)
	local words = {}
	for word in s:gmatch("%S+") do
		if not laughter(word) then
			table.insert(words, word)
		end
	end
	s = table.concat(words, " ")
	s = s:gsub("%s+%.", ".")
	while s:find("%.%s*%.") do
		s = s:gsub("%.%s*%.", ".")
	end
	s = s:gsub("^[%s%.]+", "")
	if s ~= "" and not s:match("%.$") then
		s ..= "."
	end
	return s
end

function Voice.Machine(text)
	if type(text) ~= "string" then
		return text
	end
	-- characters the escape doesn't need inside text: bring them back so contractions read
	local s = text:gsub("&apos;", "'"):gsub("&#39;", "'"):gsub("&quot;", '"')
	-- keep the remaining entities out of reach of upper() and the punctuation rules
	local kept = {}
	s = s:gsub("&#?%w+;", function(entity)
		table.insert(kept, entity)
		return "\1" .. #kept .. "\2"
	end)
	s = flatten(s)
	s = s:gsub("\1(%d+)\2", function(i)
		return kept[tonumber(i)]
	end)
	return if s == "" then Voice.Silent else s
end

return Voice
