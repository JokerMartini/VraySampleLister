/********************************************************
:Created By:			John Martini
:Company:				JokerMartini
:Site:					http://JokerMartini.com
:Email:					jokermartini@gmail.com
:Client:				
:Purpose:
:History:
:Todo:
	- clickable headers to sort by classname or node name
:Bugs:
:Tests:
:Notes:
********************************************************/
try(destroyDialog VraySubdivTool.instUI;VraySubdivTool.instUI=undefined)catch()

--Structure containing the tool
struct VraySubdivTool
(
	versionStr="V:0.00.01",
	instUI=undefined,
	toolname = "Vray Subdiv Lister",

	/********************************************************
	Variables
	********************************************************/

	/********************************************************
	Functions
	********************************************************/	
	
	/********************************************************
	Rollouts
	********************************************************/
	fn UI=
	(
		rollout VraySubdivToolRO "VraySubdivTool"
		(
			struct item (node=undefined, name="", classname="", props=#())
			struct property (name="", value=0)

			dotNetControl uiTabs "TabControl" pos:[0,0]
			dotNetControl uiList "DataGridView" pos:[0,80]
			spinner uiSubdivs "Subdivs: " type:#integer range:[1,1000,8] fieldwidth:55 pos:[15,45]
			button uiSetValues "=" width:30 height:30 pos:[140,37] tooltip:"Set selected values."
			button uiIncreaseValues "+" width:30 height:30 pos:[170,37] tooltip:"Increase selected values relative to their current values."
			button uiDecreaseValues "-" width:30 height:30 pos:[200,37] tooltip:"Decrease selected values relative to their current values."
			--label uiSampleDisplayLabels "                Subdivs:\n   Per AA-Samples:\nPer Pixel-Samples:" pos:[240,32] enabled:false height:45
			label uiSampleDisplayInfo "" pos:[240,40] enabled:false width:150 height:30

			/* UI Functions */
			fn ResizeUI = 
			(
				local width = VraySubdivToolRO.width
				local height = VraySubdivToolRO.height

				uiTabs.width = width
				uiList.width = width
				uiList.height = height-80
			)

			fn GetTabIndex ctrl: =
			(
				return ctrl.SelectedIndex
			)


			fn isVRayCurrent = matchPattern (renderers.production as string) pattern:"*V_RAY*"

			fn Sqr num:0 = 
			(
				return (pow num 2)
			)

			fn GetAASamples minAA:1 maxAA:1 =
			(
				if (isVRayCurrent()) do
				(
					rEngine = renderers.current
					imageSampler = if isProperty rEngine #imageSampler_type then rEngine.imageSampler_type else 1
					
					fixed_Subdivs = if isProperty rEngine #fixedRate_subdivs then rEngine.fixedRate_subdivs else 1

					dmc_baseSubdivs = if isProperty rEngine #twoLevel_baseSubdivs then rEngine.twoLevel_baseSubdivs else 1
					dmc_fineSubdivs = if isProperty rEngine #twoLevel_fineSubdivs then rEngine.twoLevel_fineSubdivs else 1

					adaptive_minRate = if isProperty rEngine #adaptiveSubdivision_minRate then rEngine.adaptiveSubdivision_minRate else 1
					adaptive_maxRate = if isProperty rEngine #adaptiveSubdivision_maxRate then rEngine.adaptiveSubdivision_maxRate else 1

					progressiveMin = if isProperty rEngine #progressive_minSamples then rEngine.progressive_minSamples else 1
					progressiveMax = if isProperty rEngine #progressive_maxSamples then rEngine.progressive_maxSamples else 1

					case imageSampler of
					(
						0: /*Fixed*/
						(
							minAA = maxAA = Sqr num:fixed_subdivs
						)
						1: /*Adaptive*/
						(
							minAA = Sqr num:dmc_baseSubdivs
							maxAA = Sqr num:dmc_fineSubdivs
						)
						2: /*Adaptive subdivision*/
						(
							minAA = 1 -- adaptive_minRate<0? 0 : (1<<adaptive_minRate) --commented out in original
							maxAA = 1 -- adaptive_maxRate<0? 0 : (1<<adaptive_maxRate) --commented out in original
							/*	Translates
								minAA=1; // adaptive_minRate<0? 0 : (1<<adaptive_minRate);
								if (adaptive_minRate < 0) then (minAA = 0) else (minAA = pow 2 adaptive_minRate)
							*/
						)
						3: /*Progressive*/
						(
							minAA = Sqr num:progressiveMin
							maxAA = Sqr num:progressiveMax
						)
					)
				)
				return [minAA,maxAA]
			)

			fn GetVraySamplingInfo subdivs:0 = 
			(
				local str = "Per AA Samples:\t N/A\nPer Pixel Samples:\t N/A"
				
				if (isVRayCurrent()) do
				(
					rEngine = renderers.current

					/*Figure out the min/max AA samples*/
					vraySamples = GetAASamples()
					minAA = vraySamples[1]
					maxAA = vraySamples[2]

					minShadingRate = if isProperty rEngine #imageSampler_shadingRate then rEngine.imageSampler_shadingRate else 1
					divideShadingSubdivs = if isProperty rEngine #dmc_balance_subdivs then rEngine.dmc_balance_subdivs else true

					/* 
						samplingInfo.useInterpolation is true only for stuff using the prepasses, 
						like the irradiance map and interpolated glossy reflections/refractions.
						--if (samplingInfo.useInterpolation) do divideShadingSubdivs = false;
					*/
					useInterpolation = false

					subdivsMult = if isProperty rEngine #dmc_subdivs_mult then rEngine.dmc_subdivs_mult else 1 

					/*Expand the value to the max. AA samples*/
					nsamples = Sqr num:subdivs
					if (not useInterpolation) OR (subdivsMult > 1e6) do --(subdivsMult > 1e-6f) 
					(
						nsamples = (ceil (nsamples * subdivsMult)) as integer
					)

					if not divideShadingSubdivs then
					(
						nsamples = amax #(minShadingRate, nsamples*maxAA)
					)else(
						nsamples = amax #(nsamples, maxAA*minShadingRate)
					)

					minAdaptiveAmount = if isProperty rEngine #dmc_earlyTermination_amount then rEngine.dmc_earlyTermination_amount as float else 1.0 --? pb_dmc_adaptive_amount
					minAdaptiveSamples = if isProperty rEngine #dmc_earlyTermination_minSamples then rEngine.dmc_earlyTermination_minSamples as integer else 1 --? pb_dmc_adaptive_minSamples

					/*First figure out the min/max samples per AA sample*/
					perAA = nsamples/maxAA as float
					pixelMax = nsamples
					aaMax = ceil perAA

					minSmp = amax #(minAdaptiveSamples, ceil(perAA*(1.0-minAdaptiveAmount)) )
				 	if (minSmp > perAA) do minSmp = perAA
					aaMin = ceil(minSmp)

					pixelMin = ceil(minSmp*minAA)

					-- which value to use???
					--items = #(perAA, pixelMax, aaMax, minSmp, aaMin, pixelMin, nsamples, maxAA, minAA)
					--for i in items do print i

					str = "Per AA Samples:    " + (minSmp as integer) as string + "/" + (perAA as integer) as string
					str += "\nPer Pixel Samples:  " + (pixelMin as integer) as string + "/" + (pixelMax as integer) as string
				)
				str
			)

			fn GetSelectedIndices =
			(
				local indices = #()
				if uiList.Rows.count >= 1 do
				(
					for i = 1 to uiList.rows.count do
					(
						if uiList.rows.Item[i-1].Selected do
						(
							append indices (i-1)
						)
					)
				)
				return indices
			)

			fn GetListNodes = 
			(
				local indices = GetSelectedIndices()
				local nodes = #()

				for i in indices do 
				(
					append nodes (uiList.rows.item[i].tag.value)
				)

				return nodes
			)

			fn UpdateSampleDisplay =
			(
				local count = uiList.SelectedCells.count
				if count >= 1 then
				(
					local item = uiList.SelectedCells.item[0]

					-- props start at column index 2
					if item.ColumnIndex >= 2 AND item.RowIndex >= 0 AND item.value != undefined then
					(
						uiSampleDisplayInfo.text = GetVraySamplingInfo subdivs:item.value
					)else(
						uiSampleDisplayInfo.text = ""
					)
				)else(
					uiSampleDisplayInfo.text = ""
				)
			)

			fn CalculateColor val:0 maxValue:256 startColor:yellow endColor:red =
			(
				local col = startColor
				local percent = 100 * val / maxValue
				if val > maxValue do val = maxValue
				k = (val as float) / maxValue
				local col = startColor * (1 - k) + endColor * k

				return col
			)

			fn StyleCell cell:undefined value:0 = 
			(
				if cell != undefined do
				(
					local col = CalculateColor val:value
					local newStyle = dotNetObject "System.Windows.Forms.DataGridViewCellStyle"
					newStyle.foreColor = (dotNetClass "system.drawing.color").FromARGB col.r col.g col.b
					cell.style = newStyle

					-- Tooltip displaying calculations
					cell.ToolTipText = GetVraySamplingInfo subdivs:value
				)
			)

			fn SetSubdivValues value:0 method:#set =
			(
				local selCellCount = uiList.SelectedCells.count
				if selCellCount >= 1 do
				(
					-- get selected cell's 'max property' from the columnTag and 'max node' by the rowTag
					for i = 1 to selCellCount do
					(
						local columnIndex = uiList.SelectedCells.Item[i-1].ColumnIndex
						local rowIndex = uiList.SelectedCells.Item[i-1].RowIndex

						local prop = uiList.columns.item[columnIndex].tag.value
						local node = uiList.rows.item[rowIndex].tag.value

						--format "%--%\n"prop node

						-- ignore first column since it's just the nodes name
						if columnIndex != 0 do
						(
							if node != undefined do
							(
								if isProperty node prop do
								(
									local curVal = GetProperty node prop 

									local newval = case method of
									(
										#set:(value)
										#decrease:(curVal -= value)
										#increase:(curVal += value)
									)

									-- limit lowest number to 1
									if newVal < 1 do newVal = 1
									SetProperty node prop newVal
									uiList.SelectedCells.Item[i-1].value = newVal

									-- color cell based on value
									StyleCell cell:uiList.SelectedCells.Item[i-1] value:newVal
								)
							)
						)
					)
				)
			)

			fn IsPropertyUsed nodes: prop: =
			(
				for n in nodes where IsProperty n prop do 
				(
					return true
				)
				return false
			)

			fn CompareClassNames str1 str2 = 
			(
				stricmp str1.classname str2.classname
			)

			fn CollectNodeData nodes:undefined props:#() = 
			(
				local data = #()
				
				for n in nodes do
				(
					x = item node:n name:n.name classname:(classof n as string) props:#() 
					
					for p in props where (isProperty n p) do
					(
						append x.props (property name:p value:(GetProperty n p))
					)
					-- allows us to ignore nodes without any vray related props
					if x.props.count != 0 do
					(
						append data x
					)
				)
				-- sorts the data collected by the node classes alphabetically
				qsort data CompareClassNames
				data
			)

			/********************************************************
			DotNet | Populate Initial DataGridView Contents
			-- looks for an array containing four elements #(control, header text, read only, sizing, alignment)
			********************************************************/
			fn GenerateColumns columns:#() =
			(
				local dnColumns = #()

				for n in columns do
				(
					local newColumn
					case n[1] of
					(
						#Bool: 
						(
							newColumn = dotNetObject "DataGridViewCheckBoxColumn"
							newColumn.flatStyle = newColumn.flatStyle.Popup
						)
						#Button: 
						(
							newColumn = dotNetObject "DataGridViewButtonColumn"
							newColumn.flatStyle = newColumn.flatStyle.Popup
							--newColumn.DefaultCellStyle.ForeColor = newColumn.DefaultCellStyle.ForeColor.FromARGB 10 10 10
							--newColumn.DefaultCellStyle.BackColor = newColumn.DefaultCellStyle.BackColor.FromARGB 60 60 60
						)
						#Text: 
						(
							newColumn = dotNetObject "DataGridViewTextBoxColumn"
						)
						#List: 
						(
							newColumn = dotNetObject "DataGridViewComboBoxColumn"
						)
					)
					case n[4] of
					(       
						false: 
						(
							newColumn.Resizable = newColumn.Resizable.false
							newColumn.AutoSizeMode = newColumn.AutoSizeMode.DisplayedCells
						)
						true: 
						(
							newColumn.Resizable = newColumn.Resizable.true
							newColumn.AutoSizeMode = newColumn.AutoSizeMode.Fill
						)
					)
					newColumn.DefaultCellStyle.Alignment = case n[5] of
					(
						#Right: newColumn.DefaultCellStyle.Alignment.MiddleRight
						#Center: newColumn.DefaultCellStyle.Alignment.MiddleCenter
						#Left: newColumn.DefaultCellStyle.Alignment.MiddleLeft
						Default: newColumn.DefaultCellStyle.Alignment.MiddleCenter
					)

					newColumn.HeaderText = n[2]
					newColumn.ReadOnly = n[3]
					newColumn.sortMode = newColumn.sortMode.NotSortable
					newColumn.tag = dotNetMXSValue n[2] -- store property name
					append dnColumns newColumn
				)
				dnColumns
			)
	
			fn PopulateList ctrl:unsupplied nodes:#() props:#() =
			(
				--Info Logging Start
				clearlistener()
				RunStartTime = (timestamp())
				RunStartMemory = heapfree

				-- collect only the properties which have been used at least once in the scene
				local usedProps = #()
				for p in props where (IsPropertyUsed nodes:nodes prop:p) do append usedProps p
				props = copy usedProps #nomap

				local data = CollectNodeData nodes:nodes props:props

				/* 
					Generate Columns 
					- first column is always node name, remaining columns are props
				*/
				local colArr = #()
				append colArr #(#Text, "name", true, true, #left) -- node name
				append colArr #(#Text, "classname", true, true, #left) -- node's class name
				for p in props do append colArr #(#Text, p, true, true, #center) --node properties
				local dnColumns = GenerateColumns columns:colArr
				ctrl.Columns.AddRange dnColumns

				/* 
					Generate Rows 
					- row Tag value should contain dotNetMXSValue of the node in order to apply settings to correct node in scene
				*/
				for d in data do
				(
					newRow = dotNetObject "DataGridViewRow"
					newRow.height = 22
					newRow.tag = dotNetMXSValue d.node

					ctrl.rows.add newRow

					/* Set first column as name of node */
					newRow.cells.item[0].value = d.name

					/* Set second column as class name of node */
					newRow.cells.item[1].value = d.classname
 					
 					/* 
 						Set each column's property value
 						-- loop through each column and assign the value to the correct column
 						-- the column which the property is assigned matches the index of the property found in the 'props' array
 					*/
					for i=1 to d.props.count do
					(
						local propName = d.props[i].name
						local propValue = d.props[i].value

						-- offset 1 to respect dotnet starting at 0
						-- additionally offset 1 becasuse column '1' is now classname so props start at column 2
						local id = (findItem props propName) + 1 

						newRow.cells.item[id].value = propValue
						StyleCell cell:newRow.cells.item[id] value:propValue	

						-- Tooltip displaying calculations
						-- newRow.cells.item[id].ToolTipText = GetVraySamplingInfo subdivs:propValue
						--newRow.cells.item[id].ToolTipText = "Per AA Samples:\t 0/100\nPer Pixel Samples:\t 0/200 "			
					)
				)

				ctrl.Update()

				--Info Logging End
				RunEndTime = (timestamp())
				RunEndMemory = heapfree
				RunMemoryUsed = RunStartMemory - RunEndMemory
				RunTimeLength = ((dotnetclass "TimeSpan").FromMilliseconds (RunEndTime - RunStartTime)).ToString()
				Format "\n-----------------------------------------------------------"
				Format "\nMemory Used:\t%\n" RunMemoryUsed	
				Format "Process Time:\t%\n" RunTimeLength
			)

			/* 
				All Scene/File Materials - both used and unused 
				- this method makes it easier to collect all sub vray materials
			*/	
			fn GetVraySceneMaterials = 
			(
				local sceneMtls = #()
				for m in material.classes do 
				(
					if (matchpattern (m as string) pattern:"vray*" ignorecase:true) do
					(
						mtls = getClassInstances m
						if mtls.count >= 1 do join sceneMtls mtls
						--format "%--%\n" mtls.count m
					)
				)
				sceneMtls
			)

			fn GetVraySceneMaps = 
			(
				local sceneMaps = #()
				for m in TextureMap.classes do 
				(
					if (matchpattern (m as string) pattern:"vray*" ignorecase:true) do
					(
						mtls = getClassInstances m
						if mtls.count >= 1 do join sceneMaps mtls
						--format "%--%\n" mtls.count m
					)
				)
				sceneMaps
			)

			fn PopulateDataGridview ctrl:unsupplied index:0 =
			(
				ctrl.columns.Clear()

				case index of
				(
					0: 
					(
						Print "Lights"
						local vrayProps = #(#subdivs, #shape_subdivs, #shadow_subdivs, #Resolution)
						PopulateList ctrl:ctrl nodes:lights props:vrayProps
					)
					1: 
					(
						Print "Materials"
						local vrayProps = #(#subdivs, #reflection_subdivs, #refraction_subdivs, #specular_subdivs, #single_scatter_subdivs, #directLight_subdivs, #glossy_subdivs, #primary_reflection_subdivs, #seconary_reflection_subdivs, #raytraced_subdivs)
						
						-- collect all vray materials in scene
						local materials = GetVraySceneMaterials()
						PopulateList ctrl:ctrl nodes:materials props:vrayProps
					)
					2:
					(	
						Print "Maps"
						local vrayProps = #(#subdivs)
						
						-- collect all vray materials in scene
						local maps = GetVraySceneMaps()
						PopulateList ctrl:ctrl nodes:maps props:vrayProps
					)
					3:
					(	
						Print "Atmospherics"
						local vrayProps = #(#subdivs)
						atms = for i = 1 to numAtmospherics collect (getAtmospheric i)
						PopulateList ctrl:ctrl nodes:atms props:vrayProps
					)
				)
			)

			fn StyleDataGridView ctrl:unsupplied =
			(
				if ctrl != unsupplied do
				(
					ctrl.MultiSelect = true
					ctrl.AllowUserToAddRows = false
					ctrl.AllowUserToDeleteRows = false
					ctrl.AllowUserToResizeRows = false
					ctrl.AllowUserToResizeColumns = true
					ctrl.AllowUserToOrderColumns = false
					ctrl.AutoSize = True
					ctrl.ShowEditingIcon = false
					ctrl.RowHeadersVisible = false
					ctrl.ColumnHeadersBorderStyle = ctrl.ColumnHeadersBorderStyle.None
					ctrl.ColumnHeadersHeightSizeMode = ctrl.ColumnHeadersHeightSizeMode.DisableResizing
					ctrl.SelectionMode = ctrl.SelectionMode.CellSelect
					ctrl.ColumnHeadersVisible = true
					ctrl.BorderStyle = ctrl.BorderStyle.FixedSingle
					ctrl.AutoResizeColumns()

					/* Colors and font */
					ctrl.ForeColor = ctrl.ForeColor.FromARGB 220 220 220
					ctrl.BackColor = ctrl.ForeColor.FromARGB 50 50 50
					ctrl.GridColor = ctrl.ForeColor.FromARGB 50 50 50
					ctrl.BackgroundColor = ctrl.ForeColor.FromARGB 50 50 50
					ctrl.DefaultCellStyle.BackColor = ctrl.ForeColor.FromARGB 50 50 50
					ctrl.AlternatingRowsDefaultCellStyle.BackColor = ctrl.AlternatingRowsDefaultCellStyle.BackColor.FromARGB 45 45 45
					ctrl.Font = dotNetObject "System.Drawing.Font" "Arial" 8 ctrl.font.style.Regular
					ctrl.AdvancedCellBorderStyle.Left = ctrl.AdvancedCellBorderStyle.Left.None
					ctrl.AdvancedCellBorderStyle.Right = ctrl.AdvancedCellBorderStyle.Right.None
				)
			)

			fn StyleListview ctrl:unsupplied =
			(
				ctrl.view = ctrl.View.details
				ctrl.HideSelection = false
				ctrl.FullRowSelect = true
				ctrl.GridLines = true 		
				ctrl.MultiSelect = true
				ctrl.BackColor = (dotnetclass "System.Drawing.SystemColors").Menu
				ctrl.ShowGroups = true
			)

			fn StyleTabs ctrl:unsupplied items:#() =
			(
				if ctrl != unsupplied do
				(
					ctrl.TabPages.Clear()
					ctrl.sizeMode = ctrl.sizeMode.fixed	
					ctrl.itemSize = dotnetObject "System.Drawing.Size" 80 25
					for i in items do ctrl.TabPages.add i
					tabStyle = dotNetClass "System.Windows.Forms.TabAppearance"
					ctrl.Appearance = tabStyle.buttons
					ctrl.BackColor = colMax
					ctrl.height = 30
				)
			)

			/* UI Actions */
			on uiSetValues pressed do 
			(
				SetSubdivValues value:uiSubdivs.value method:#set
				UpdateSampleDisplay()
			)

			on uiIncreaseValues pressed do 
			(
				SetSubdivValues value:uiSubdivs.value method:#increase
				UpdateSampleDisplay()
			)

			on uiDecreaseValues pressed do 
			(
				SetSubdivValues value:uiSubdivs.value method:#decrease
				UpdateSampleDisplay()
			)

			on uiTabs MouseUp s e do
			(
				PopulateDataGridview ctrl:uiList index:(GetTabIndex ctrl:uiTabs)
			)

			on uiList CellDoubleClick s e do
			(
				if e.ColumnIndex == 0 AND e.RowIndex >= 0 do
 				(
 					local tagValue = uiList.rows.item[e.RowIndex].tag.value
 					local tagClass = toLower ((superclassof tagValue) as string)

 					print tagClass
 					case tagClass of
 					(
 						"light":
 						(
 							if keyboard.controlPressed then (selectMore tagValue) else (select tagValue)
 						)
						"material":
						(
							SME.Open() 
							sme.DeleteView (sme.GetViewByName "QuickEdit") false
							sme.CreateView "QuickEdit"

							mtl = tagValue
							--needed because pos parameter is in/out (a reference)
							NodePos = [0,0] + [0,0]
							-- get the current view
							SelView = sme.GetView sme.ActiveView
							--Assuming you have an object selected and you want that object's material in the editor
							NewNode = SelView.CreateNode mtl &NodePos

							try(
								SelView.SetSelectedNodes mtl
								sme.SetMtlInParamEditor mtl
								SelView.ZoomExtents type:#all
							)catch() --only max 2014 and up
						)
						"texturemap":
						(
							SME.Open() 
							sme.DeleteView (sme.GetViewByName "QuickEdit") false
							sme.CreateView "QuickEdit"

							mtl = tagValue
							--needed because pos parameter is in/out (a reference)
							NodePos = [0,0] + [0,0]
							-- get the current view
							SelView = sme.GetView sme.ActiveView
							--Assuming you have an object selected and you want that object's material in the editor
							NewNode = SelView.CreateNode mtl &NodePos

							try(
								SelView.SetSelectedNodes mtl
								sme.SetMtlInParamEditor mtl
								SelView.ZoomExtents type:#all
							)catch() --only max 2014 and up
						)
 					)
 				)
			)

			on uiList SelectionChanged s e do
			(
				UpdateSampleDisplay()
			)

			on uiList CellClick s e do
			(
--				format "%----%\n" e.ColumnIndex e.RowIndex
				UpdateSampleDisplay()
-- 				if e.ColumnIndex == 1 AND e.RowIndex >= 0 do
-- 				(
-- 				)
			)

			on VraySubdivToolRO resized val do
			(
				ResizeUI()
			)

			on VraySubdivToolRO open do
			(
				VraySubdivToolRO.title = VraySubdivTool.toolname + " " + versionStr
				StyleTabs ctrl:uiTabs items:#("Lights", "Materials", "Maps", "Atmospherics")
				StyleDataGridview ctrl:uiList
				PopulateDataGridview ctrl:uiList index:(GetTabIndex ctrl:uiTabs)
				ResizeUI()
			)
		)
	),
	
	fn run=
	(
		if instUI==undefined then
		(
			instUI=UI()
			createDialog instUI width:400 height:500 style:#(#style_SysMenu, #style_titlebar, #style_minimizebox, #style_resizing)
		)else
		(
			destroyDialog instUI
			instUI=undefined
		)
	),

	fn getRollouts=#(ui()),

	macro=
	(
-- 		macroScript VraySubdivTool 
-- 			category:"PEN Test"
-- 			buttonText:"Test Tool"
-- 		(
-- 			on execute do
-- 			(
-- 				if VraySubdivTool!=undefined do VraySubdivTool.run()
-- 			)
-- 		)
	)
	
)
clearlistener()
VraySubdivTool=VraySubdivTool()
VraySubdivTool.run()
 
