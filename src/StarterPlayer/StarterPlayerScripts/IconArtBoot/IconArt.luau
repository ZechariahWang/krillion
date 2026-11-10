--!strict
-- Artwork renderer. Controllers keep their original text and comparisons.
local TextService = game:GetService("TextService")
local Catalog = require(script.Parent.IconCatalog)
local IconArt = {}
local bound = setmetatable({}, {__mode = "k"})
local cache = {}
local cacheCount = 0
local MARK = utf8.char(0x25CF)
local glyphs = {}
for glyph in Catalog.Glyph do table.insert(glyphs, glyph) end
table.sort(glyphs, function(a,b) return #a > #b end)

local function escape(s)
 return (s:gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;"))
end
local function scan(text, rich)
 local output, plain, slots = {}, {}, {}
 local i = 1
 while i <= #text do
  if rich and text:sub(i,i) == "<" then
   local last = text:find(">",i,true)
   if last then table.insert(output,text:sub(i,last)); i=last+1; continue end
  end
  local found
  for _,glyph in glyphs do
   if text:sub(i,i+#glyph-1)==glyph then found=glyph; break end
  end
  if found=="?" and not text:match("^%s*%?%s*$") then found=nil end
  if found then
   table.insert(output,'<font transparency="1">'..MARK..'</font>')
   table.insert(plain,MARK)
   table.insert(slots,Catalog.Glyph[found])
   i += #found
  else
   local nextByte = utf8.offset(text,2,i) or (#text+1)
   local char = text:sub(i,nextByte-1)
   table.insert(output,if rich then char else escape(char))
   table.insert(plain,char)
   i=nextByte
  end
 end
 return table.concat(output),table.concat(plain),slots
end

local function measure(label, text, size, width, rich)
 local font = label.FontFace
 local key = font.Family..tostring(font.Weight)..tostring(font.Style)..":"..size..":"..width..":"..tostring(rich)..":"..text
 if cache[key] then return cache[key] end
 local params=Instance.new("GetTextBoundsParams")
 params.Text=text; params.Font=font; params.Size=size; params.Width=width; params.RichText=rich
 local ok,result=pcall(function() return TextService:GetTextBoundsAsync(params) end)
 params:Destroy()
 if not ok then return Vector2.new(#text*size*0.5,size*1.2) end
 if cacheCount>3000 then table.clear(cache); cacheCount=0 end
 cache[key]=result; cacheCount+=1
 return result
end
local function addImage(layer, asset, size, x,y,z, transparency)
 if asset:sub(1,1)=="@" then
  local symbol=Instance.new("TextLabel")
  symbol.Name="ArtSymbol";symbol.BackgroundTransparency=1
  symbol.Size=UDim2.fromOffset(size,size);symbol.Position=UDim2.fromOffset(x,y)
  symbol.Text=({["@right"]="▶",["@left"]="◀",["@up"]="▲",["@down"]="▼",["@close"]="×"})[asset] or "•"
  symbol.Font=Enum.Font.FredokaOne;symbol.TextScaled=true
  symbol.TextColor3=Color3.fromRGB(255,245,220);symbol.TextStrokeColor3=Color3.fromRGB(43,10,67)
  symbol.TextStrokeTransparency=0;symbol.TextTransparency=transparency;symbol.ZIndex=z;symbol.Parent=layer
  return symbol
 end
 local image=Instance.new("ImageLabel")
 image.Name="ArtImage"; image.BackgroundTransparency=1
 image.Image=asset; image.ScaleType=Enum.ScaleType.Fit
 image.Size=UDim2.fromOffset(size,size); image.Position=UDim2.fromOffset(x,y)
 image.ZIndex=z; image.ImageTransparency=transparency
 image.Parent=layer
 return image
end
local function nativeKind(text,label)
 local trim=text:match("^%s*(.-)%s*$")
 if trim=="+" then return "Plus" end
 if trim=="!" and (label.Name=="Badge" or label.Parent and label.Parent.Name=="Badge") then return "Bang" end
 if trim==">" then return "Right" end
 if trim=="<" then return "Left" end
 if trim=="-" and (label.Name=="CollapseButton" or label.Parent and label.Parent.Name=="CollapseButton") then return "Minus" end
 if trim=="×" or trim=="✕" or trim=="✖" or trim=="❌" or trim=="X" then return "Close" end
 return nil
end
local function native(layer,kind,w,h,z,alpha)
 local side=math.min(w,h)*0.64
 if kind=="Bang" then
  for _,piece in {{0.5,0.38,0.16,0.48},{0.5,0.78,0.18,0.18}} do
   local part=Instance.new("Frame");part.Name="ArtBadgeStroke";part.AnchorPoint=Vector2.new(0.5,0.5)
   part.Position=UDim2.fromScale(piece[1],piece[2]);part.Size=UDim2.fromOffset(side*piece[3],side*piece[4])
   part.BorderSizePixel=0;part.BackgroundColor3=Color3.fromRGB(255,245,220);part.BackgroundTransparency=alpha;part.ZIndex=z
   local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(1,0);corner.Parent=part
   local outline=Instance.new("UIStroke");outline.Color=Color3.fromRGB(43,10,67);outline.Thickness=math.max(1,side*0.05);outline.Transparency=alpha;outline.Parent=part
   part.Parent=layer
  end
  return
 end
 if kind=="Right" or kind=="Left" then
  local arrow=Instance.new("TextLabel")
  arrow.Name="ArtArrow";arrow.BackgroundTransparency=1
  arrow.Size=UDim2.fromScale(1,1);arrow.Text=if kind=="Right" then "›" else "‹"
  arrow.Font=Enum.Font.FredokaOne;arrow.TextScaled=true
  arrow.TextColor3=Color3.fromRGB(255,245,220);arrow.TextTransparency=alpha
  arrow.TextStrokeColor3=Color3.fromRGB(43,10,67);arrow.TextStrokeTransparency=0;arrow.ZIndex=z;arrow.Parent=layer
  return
 end
 for i,rotation in {if kind=="Close" then 45 else 0, if kind=="Close" then -45 else 90} do
  if kind=="Minus" and i==2 then break end
  local bar=Instance.new("Frame")
  bar.Name="ArtStroke"; bar.AnchorPoint=Vector2.new(0.5,0.5)
  bar.Position=UDim2.fromScale(0.5,0.5)
  bar.Size=UDim2.fromOffset(side,math.max(3,side*0.17)); bar.Rotation=rotation
  bar.BackgroundColor3=Color3.fromRGB(255,245,220); bar.BackgroundTransparency=alpha; bar.BorderSizePixel=0; bar.ZIndex=z
  local corner=Instance.new("UICorner"); corner.CornerRadius=UDim.new(1,0); corner.Parent=bar
  local stroke=Instance.new("UIStroke"); stroke.Color=Color3.fromRGB(43,10,67); stroke.Thickness=math.max(1,side*0.065); stroke.Transparency=alpha; stroke.Parent=bar
  bar.Parent=layer
 end
end

local STYLE={"FontFace","TextSize","TextScaled","TextWrapped","TextColor3","TextTransparency","TextStrokeColor3","TextStrokeTransparency","TextXAlignment","TextYAlignment","LineHeight","TextTruncate","ZIndex"}
local function render(label,state)
 state.token += 1
 local token=state.token
 if label.Parent==nil then return end
 -- The authored lifted caption already draws this button's text.
 if label.Name~="LiftedText" and label:FindFirstChild("LiftedText") then return end
 local text=label.Text
 local masked,plain,slots=scan(text,label.RichText)
 local kind=nativeKind(text,label)
 if #slots==0 and kind==nil then
  if state.layer then state.layer:Destroy();state.layer=nil; label.MaxVisibleGraphemes=state.originalMax end
  return
 end
 if label:FindFirstChild("PetArtwork") then return end
 if state.layer then state.layer:Destroy() end
 local layer=Instance.new("Frame")
 layer.Name="IconArtLayer"; layer.Size=UDim2.fromScale(1,1)
 layer.BackgroundTransparency=1; layer.ClipsDescendants=true; layer.ZIndex=label.ZIndex+1
 layer.Parent=label; state.layer=layer
 label.MaxVisibleGraphemes=0
 local uiScale=1
 local current=label
 while current and not current:IsA("LayerCollector") do
  if current:IsA("GuiObject") then
   for _,scale in current:GetChildren() do if scale:IsA("UIScale") then uiScale*=scale.Scale end end
  end
  current=current.Parent
 end
 uiScale=math.max(uiScale,0.001)
 local w,h=layer.AbsoluteSize.X/uiScale,layer.AbsoluteSize.Y/uiScale
 if w<=0 or h<=0 then return end
 if kind then native(layer,kind,w,h,label.ZIndex+2,label.TextTransparency); return end
 local stripped=plain:gsub("<[^>]*>",""):gsub("&amp;","&"):gsub("&lt;","<"):gsub("&gt;",">")
 if stripped:gsub(MARK,""):match("^%s*$") and #slots==1 then
  local side=math.min(w,h)*0.95
  addImage(layer,slots[1],side,(w-side)/2,(h-side)/2,label.ZIndex+2,label.TextTransparency)
  return
 end
 task.spawn(function()
  local caption=Instance.new("TextLabel")
  caption.Name="ArtCaption"; caption.Size=UDim2.fromScale(1,1)
  caption.BackgroundTransparency=1; caption.RichText=true
  for _,prop in STYLE do caption[prop]=label[prop] end
  caption.MaxVisibleGraphemes=-1; caption.Text=masked; caption.ZIndex=label.ZIndex+1
  for _,child in label:GetChildren() do
   if child:IsA("UITextSizeConstraint") then child:Clone().Parent=caption
   elseif child:IsA("UIStroke") then local clone=child:Clone(); clone.Name="ArtOutline"; clone.Parent=caption end
  end
  if token~=state.token or layer.Parent==nil then caption:Destroy();return end
  caption.Parent=layer
  local width=if label.TextWrapped then w else 100000
  local size=label.TextSize
  if label.TextScaled then
   local limit=label:FindFirstChildOfClass("UITextSizeConstraint")
   local low=if limit then limit.MinTextSize else 1
   local high=math.min(if limit then limit.MaxTextSize else 100,h)
   for _=1,8 do
    local middle=(low+high)/2
    local bounds=measure(label,masked,middle,width,true)
    if bounds.X<=w+0.1 and bounds.Y<=h+0.1 then low=middle else high=middle end
   end
   size=low
  end
  local lineHeight=measure(label,"Ag",size,100000,false).Y*label.LineHeight
  local lines={""}
  for word in (stripped.."\n"):gmatch("(.-)\n") do
   if lines[#lines]~="" then table.insert(lines,"") end
   for unit in word:gmatch("%S+%s*") do
    local line=lines[#lines]
    local candidate=line..unit
    if label.TextWrapped and line~="" and measure(label,candidate,size,100000,false).X>w then
     table.insert(lines,unit)
    else lines[#lines]=candidate end
   end
  end
  if #lines==0 then lines={stripped} end
  local totalHeight=#lines*lineHeight
  local y=if label.TextYAlignment==Enum.TextYAlignment.Top then 0 elseif label.TextYAlignment==Enum.TextYAlignment.Bottom then h-totalHeight else (h-totalHeight)/2
  local index=0
  for _,line in lines do
   local lineWidth=measure(label,line,size,100000,false).X
   local startX=if label.TextXAlignment==Enum.TextXAlignment.Left then 0 elseif label.TextXAlignment==Enum.TextXAlignment.Right then w-lineWidth else (w-lineWidth)/2
   local pos=1
   while true do
    local a,b=line:find(MARK,pos,true)
    if not a then break end
    index+=1
    local prefix=line:sub(1,a-1)
    local left=measure(label,prefix,size,100000,false).X
    local right=measure(label,prefix..MARK,size,100000,false).X
    local side=math.min(lineHeight,size*1.22)
    if token~=state.token or layer.Parent==nil then return end
    if slots[index] then addImage(layer,slots[index],side,startX+(left+right-side)/2,y+(lineHeight-side)/2,label.ZIndex+2,label.TextTransparency) end
    pos=b+1
   end
   y+=lineHeight
  end
 end)
end

function IconArt.bind(object)
 if object:FindFirstAncestor("IconArtLayer") or object.Name=="IconArtLayer" or object.Name=="PetArtwork" then return end
 if object:IsA("ImageLabel") and object.Name=="Icon" and object.Parent and object.Parent.Name=="TopButton" and object:FindFirstAncestor("Settings") then
  object.Image=Catalog.Images.gear
  object.ImageColor3=Color3.new(1,1,1)
  return
 end
 if object:IsA("Frame") and object.Name=="CoinIcon" then
  if object:FindFirstChild("ShellArtwork") then return end
  object.BackgroundTransparency=1
  for _,v in object:GetChildren() do if v:IsA("UIStroke") then v.Enabled=false end end
  local icon=Instance.new("ImageLabel")
  icon.Name="ShellArtwork"; icon.BackgroundTransparency=1
  icon.Size=UDim2.fromScale(1.25,1.25);icon.Position=UDim2.fromScale(-0.125,-0.125)
  icon.Image=Catalog.Images.shell;icon.ScaleType=Enum.ScaleType.Fit;icon.ZIndex=object.ZIndex+1;icon.Parent=object
  return
 end
 if not (object:IsA("TextLabel") or object:IsA("TextButton")) or bound[object] then return end
 if object.Name=="ArtCaption" or object.Name=="LiftedText" and object.Parent and object.Parent.Name=="IconArtLayer" then return end
 local originalMax=object:GetAttribute("IconArtOriginalMax")
 if originalMax==nil then originalMax=object.MaxVisibleGraphemes;object:SetAttribute("IconArtOriginalMax",originalMax) end
 local inherited=object:FindFirstChild("IconArtLayer")
 if inherited then inherited:Destroy() end
 object.MaxVisibleGraphemes=originalMax
 local state={token=0,originalMax=originalMax,layer=nil,queued=false}
 bound[object]=state
 local function queue()
  if state.queued then return end
  state.queued=true
  task.defer(function()
   state.queued=false
   if object.Parent then render(object,state) end
  end)
 end
 for _,prop in {"Text","AbsoluteSize","TextSize","TextScaled","TextWrapped","TextXAlignment","TextYAlignment","TextTransparency","TextColor3","FontFace","ZIndex","RichText"} do object:GetPropertyChangedSignal(prop):Connect(queue) end
 queue()
end
function IconArt.init(playerGui)
 for _,object in playerGui:GetDescendants() do IconArt.bind(object) end
 playerGui.DescendantAdded:Connect(function(object) task.defer(IconArt.bind,object) end)
 for _,object in workspace:GetDescendants() do
  if (object:IsA("TextLabel") or object:IsA("TextButton")) and object:FindFirstAncestorWhichIsA("LayerCollector") then IconArt.bind(object) end
 end
 workspace.DescendantAdded:Connect(function(object)
  if object:IsA("TextLabel") and object:FindFirstAncestorWhichIsA("LayerCollector") then task.defer(IconArt.bind,object) end
 end)
end
return IconArt
