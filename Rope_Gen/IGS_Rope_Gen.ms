mapped fn freezeTM obj mode:#{1..2} =
(
		if mode[1] then
		(
			local lstCnt = position_List()
			obj.position.controller = lstCnt
			lstCnt[1].controller = position_xyz()
			lstCnt[2].controller = position_xyz()
			lstCnt.active = 2
			lstCnt.setName 1 "Frozen Position"
			lstCnt.setName 2 "Zero Position"
		)
		if mode[2] then
		(
			local lstCnt = rotation_List()
			obj.rotation.controller = lstCnt
			lstCnt[1].controller = euler_xyz()
			lstCnt[2].controller = euler_xyz()
			lstCnt.active = 2
			lstCnt.setName 1 "Frozen Rotation"
			lstCnt.setName 2 "Zero Rotation"
		)
		if mode[3] then
		(
			local lstCnt = scale_List()
			obj.scale.controller = lstCnt
			lstCnt[1].controller = bezier_scale()
			lstCnt[2].controller = bezier_scale()
			lstCnt.active = 2
			lstCnt.setName 1 "Frozen Scale"
			lstCnt.setName 2 "Zero Scale"
		)
		return true
)

fn createPntSegs theSpline Snake_segs: segName: = 
(	
	locatorArr=#()
	__size = ((curvelength theSpline)/Snake_segs)*0.75
	for h = 1 to (Snake_segs+1) do
	(
		spc_obj = point pos:[0,0,0] name:(uniquename segName+"_"+(h as string) ) cross:false \
		centermarker:true box:true axistripod:false wirecolor:(color 87 224 198) size:__size 
		append locatorArr spc_obj 
	)
	
	local prvLen=0
	local curvelen = curvelength theSpline
	local curveNode = nodeTransformMonitor node:theSpline forwardTransformChangeMsgs:false 
	LSLCA = attributes fxLen
	(
		parameters main
		(
			bFixLen		type:#boolean default:true
			fixedLen	type:#float	--固定curve實長
			fixedPerc	type:#float	--固定百分比
			refCurve	type:#maxObject -- 參考的curve
			offset		type:#float	--偏移
		)
	)
	for i = 1 to  (locatorArr.count) do
	(
		locatorArr[i].pos.controller = path_constraint()
		deleteKeys  locatorArr[i].controller[1]
		locatorArr[i].controller[1].controller.path  = theSpline
		locatorArr[i].controller[1].controller.follow = true
		
		-- #[ Float Script ] 固定長度
		-- 跟上一節的curve實長
		-- 若固定長度： 重算新百分比 = 跟上一節的curve實長/ 新的長度
		-- 若非固定長度： 這節的鎖定百分比(固定值)

		local newScriptController= float_script ()
		locatorArr[i].pos.controller.percent.controller = newScriptController
		custAttributes.add locatorArr[i].pos.controller.percent.controller LSLCA
		newScriptController.fixedLen.controller=bezier_float ()
		newScriptController.fixedPerc.controller=bezier_float ()
		
		local curPerc = (i-1)*(100/(locatorArr.count-1))*0.01
		local fixLen = curvelen*curPerc
		
		newScriptController.fixedLen = fixLen
		newScriptController.fixedPerc = curPerc
		newScriptController.refCurve = curveNode 
		local	sscript="
ret = 0
local refCurv = undefined
try(refCurv = this.refCurve.node)catch()
if(isvalidnode refCurv)then
(
	ret = this.fixedPerc
	if this.bFixLen then 
	(
		local nowLen = curvelength this.refCurve.node
		ret = ( this.fixedLen / nowLen )
	)
	ret += this.offset
	if(ret>=1)then ret=1
	if(ret<=0)then ret=0			
)

ret
"
		newScriptController.script=sscript	
		
		--locatorArr[i].controller[1].percent = (i-1)*(100/(locatorArr.count-1))
	)
	locatorArr[locatorArr.count].controller[1].percent = 100.0
	
	locatorArr
)

fn CreateBleBoneChain locatorArr =
(
	bleName = ( filterstring locatorArr[1].name "_")[1]
	local theblendingBone = #()
	for h = 1 to (locatorArr.count-1) do
	(
		BlendingboneChain = bonesys.createbone locatorArr[h].pos locatorArr[h+1].pos [0,0,1] 
		BlendingboneChain.boxmode = false
		BlendingboneChain.name = uniquename bleName
		BlendingboneChain.width = BlendingboneChain.height = BlendingboneChain.length/10.0
		BlendingboneChain.wirecolor = (color 153 164 174)
		BlendingboneChain.sidefins = false
		BlendingboneChain.frontfin = false
		BlendingboneChain.backfin = false
		append theblendingBone BlendingboneChain
	)
	for j = theblendingBone.count to 2 by -1 do
	(
	theblendingBone[j].parent = theblendingBone[j-1]
	)
	local BasP02 = theblendingBone[theblendingBone.count].pos
	local bonesize = theblendingBone[theblendingBone.count].height
	local endBone=BoneSys.createBone BasP02 (BasP02+[0,0,bonesize]) [0,0,1]
	endBone.boxmode = true
	endBone.width = endBone.height = theblendingBone[theblendingBone.count].width
	endBone.transform = theblendingBone[theblendingBone.count].transform
	in coordSys Local move endBone [(theblendingBone[theblendingBone.count].length),0,0]
	endBone.parent = theblendingBone[theblendingBone.count]
	endBone.name = uniquename bleName
	append theblendingBone endBone
	
	theblendingBone
)


fn createNewLine _Arr _spName = 
(
	TheNewShape = SplineShape pos:[0,0,0] name:(uniquename _spName)
	addNewSpline TheNewShape
	
	for i in 1 to _Arr.count do
	(
		addKnot TheNewShape 1 #smooth #curve _Arr[i].pos
	)
	updateShape TheNewShape
	hide TheNewShape
	
	TheNewShape
)

fn applyScriptConstLR _node: Lnode: Rnode: =  -- _node = $RMC_2  Lnode=$LHandTgt  Rnode=$RHandTgt
(
	---  2015/12/09
	-- 為了要可以握住(parent control )
	-- 捨棄使用 position constrinat 
	-- 完全改用 script 控制
	caPosConst = attributes RopeRig_PosConst
	(
		parameters LRParams
		(
			--LHandTgt	type:#maxObject
			--RHandTgt	type:#maxObject
			HandWgt  type:#float
			LHandLcP	type:#point3
			RHandLcP	type:#point3
		)
	)
	
	local newScriptController= position_script ()
	_node.pos.controller[1].controller = newScriptController
	custAttributes.add _node.pos.controller[1].controller caPosConst
	newScriptController.HandWgt .controller=bezier_float()
	newScriptController.LHandLcP.controller=bezier_point3()
	newScriptController.RHandLcP.controller=bezier_point3()
	
	--newScriptController.LHandTgt = (nodeTransformMonitor node:Lnode forwardTransformChangeMsgs:false ) 
	--newScriptController.RHandTgt = (nodeTransformMonitor node:Rnode forwardTransformChangeMsgs:false ) 
	newScriptController.AddNode "LHandTgt" Lnode 
	newScriptController.AddNode "RHandTgt" Rnode 
	--_node.pos.controller.setWeight  1 0


	_node.pos.controller	.weight[1] = 0				
	_node.pos.controller	.weight[2] = 100
	local	sscript="
ret = [0,0,0]
local refCp = undefined
try(refCp = this.LHandLcP)catch()
if(refCp != undefined )then
(
	Lpos = this.LHandLcP * LHandTgt.transform
	Rpos = this.RHandLcP * RHandTgt.transform
	ret = Lpos * (1.0 - this.HandWgt) + Rpos * this.HandWgt
)	
ret
"
	newScriptController.script=sscript	
)

try(destroydialog IGS_ChainRope_Gen )catch()
rollout IGS_ChainRope_Gen "IGS Jump Rope Gen" width:162 
(
	local WorkSpline
	local Snake_segs = 9
	local MasterCtrlBoneChain = #()
	local SecondBoneChain = #()
	
	
	fn pickSplineOnly o = classof o == line or classof o == splineShape
	label lbl1 "Segments" width:36 height:16 align:#left
	spinner spn_Sn_segs "" width:48 height:16  pos:[lbl1.pos.x+40,lbl1.pos.y] range:[3,30,9] type:#integer scale:1 align:#left
	
	pickbutton btn_PickSpline "Pick a line" width:110 height:26 filter:pickSplineOnly
	group""
	(
		button btn_generateRig "Make Rig" width:110 height:26
	)
	
	on spn_Sn_segs changed val do
	(
		Snake_segs = val
	)
	on btn_PickSpline picked obj  do
	(
		WorkSpline = obj
		btn_PickSpline.text = obj.name
	)
	on btn_generateRig pressed do
	(
		bip = (for o in geometry where ((classof o == Biped_Object) and (o.parent==undefined)) collect o)[1]
		(
			-- Get Scene Biped Hand LR
			BipLHand = (biped.getNode bip  #larm link:4)
			BipRHand = (biped.getNode bip  #rarm link:4)
			
			cneL = (BipLHand.max + BipLHand.min)*0.5
			cneR = (BipRHand.max + BipRHand.min)*0.5
			tgtPntL = point transform:BipLHand.transform wirecolor:(color 156 46 145) size:10 name:"LHandTgt" centermarker:true \
									box:false axisTripod:false cross:false
			tgtPntR = point transform:BipRHand.transform wirecolor:(color 156 46 145) size:10 name:"RHandTgt" centermarker:true \
									box:false axisTripod:false cross:false
			
			tgtPntL.pos = cneL 
			tgtPntR.pos = cneR 
			tgtPntL.parent = BipLHand
			tgtPntR.parent = BipRHand
			
			setUserProp tgtPntL "Keep" 0
			setUserProp tgtPntR "Keep" 0
			setUserProp WorkSpline "Keep" 0
			hide WorkSpline 
			freeze WorkSpline 
			-- WorkSpline = $Line001
			
			-- 主控制點
			if(true)then
			(
				const_numMainCtrl = 3 
				mainCtrlPArr = createPntSegs WorkSpline Snake_segs:const_numMainCtrl  segName:"CMst"
				-- 主控制線
				local ctrlLine = createNewLine mainCtrlPArr "ropeMCurve"
				setUserProp ctrlLine "Keep" 0
				hide ctrlLine
				freeze ctrlLine
				__size = (curvelength ctrlLine)/mainCtrlPArr.count
				delete mainCtrlPArr
				max modify mode
				select ctrlLine 
				local SPIK = Spline_IK_Control()
				addmodifier ctrlLine SPIK
				--SPIK = ctrlLine.modifiers[1]
				forcecompleteredraw()
				SPIK.linkTypes = 2  -- NO Linking
				SPIK.createHelper (SPIK.getKnotCount())
				SPIK.helper_axistripod =off
				SPIK.helper_centermarker = off	
				SPIK.box = on	
				SPIK.helper_cross = off	
				SPIK.helper_size = __size
				
				-- Spline IK 控制點
				for k = 1 to SPIK.helper_list.count do
				(
					ct = SPIK.helper_list[k]
					ct.name = "RMC_"+(k as string)
					-- 加入Position List  & Position Constrain 
					loc = ct.position
					ct.pos.controller = position_list()
					applyScriptConstLR _node:ct Lnode:tgtPntL Rnode:tgtPntR
					ct.pos.controller.available.controller = position_xyz()
					ct.pos.controller.setActive 2
					ct.pos.controller.weight[1].controller = bezier_float()
					ct.pos.controller.weight[2].controller = bezier_float()
					freezeTM ct mode:#{2}
					setUserProp ct "Keep" 0
					setTransformLockFlags ct #{7,8,9}
				)
			)
			
			-- 副控制點
			if(true)then
			(
				numsegs = spn_Sn_segs.value -- numsegs  = 7
				global secCtrlPArr = #()
				global secSLCtrlPArr = createPntSegs ctrlLine Snake_segs:numsegs  segName:"CSec_hide"
				
				for c = 1 to secSLCtrlPArr.count do -- c = 1
				(
					ct_h = secSLCtrlPArr[c]
					ct_h.box = off
					ct_h.centermarker = on
					hide ct_h
					freeze ct_h
					setUserProp ct_h "Keep" 0
					
					__size = (curvelength ctrlLine)/secSLCtrlPArr.count * 0.4
					ct = point pos:ct_h.pos name:("CSec_"+(c as string) ) cross:false \
						centermarker:false box:true axistripod:false wirecolor:(color 200 224 32) size:__size  
					--select ct
					--ct.parent = 
					-- 加入Position List  & Position Constrain 
					ct.pos.controller = position_list()
					ct.pos.controller.available.controller = position_xyz()
					ct.pos.controller[1].controller = position_constraint()
					ct.pos.controller[1].controller.appendTarget tgtPntL 0
					ct.pos.controller[1].controller.appendTarget tgtPntR 0
					ct.pos.controller[1].controller.appendTarget ct_h 100
					ct.pos.controller.Position_Constraint.controller[1].controller = bezier_float()
					ct.pos.controller.Position_Constraint.controller[2].controller = bezier_float()
					ct.pos.controller.Position_Constraint.controller[3].controller = bezier_float()
					ct.pos.controller.setActive 2
					
					ot = orientation_constraint()
					ct.rotation.controller =  rotation_list()
					ct.rotation.controller[1].controller = ot
					ct.rotation.controller.available.controller = euler_xyz()
					ct.rotation.controller.setActive 2
					for k = 1 to SPIK.helper_list.count do
					(
						-- 
						local thisCtRatio = c / secSLCtrlPArr.count as float
						local tgrRatio = k / SPIK.helper_list.count  as float
						local distRatio =  1 - abs( thisCtRatio - tgrRatio )
						distRatio = distRatio * distRatio * distRatio * 100
						if(distRatio >100)then
							distRatio = 100
						
						ct.rotation.controller[1].controller.appendTarget  SPIK.helper_list[k] distRatio 
					)
					
					
					setUserProp ct "Keep" 0
					append secCtrlPArr ct
				)
				max select none
			)
			
			
			-- Up node 
			local upNdArr = #()
			if(true)then
			(
				numsegs = spn_Sn_segs.value -- numsegs  = 7
				local PArr = createPntSegs WorkSpline Snake_segs:numsegs  segName:"CMst_up"
				
				local ctrlLine_up = createNewLine PArr "ropeMupCurve"
				setUserProp ctrlLine_up "Keep" 0
				ctrlLine_up.pos = [ctrlLine_up.pos.x , ctrlLine_up.pos.y, ctrlLine_up.pos.z +10]
				hide ctrlLine_up
				freeze ctrlLine_up
				delete PArr
				max modify mode
				select ctrlLine_up
				local SPIK_up = Spline_IK_Control()
				addmodifier ctrlLine_up SPIK_up
				forcecompleteredraw()
				SPIK_up.linkTypes = 2 
				SPIK_up.createHelper (SPIK_up.getKnotCount())
				SPIK_up.helper_axistripod =off
				SPIK_up.helper_centermarker = on	
				SPIK_up.box = off
				SPIK_up.helper_cross = off	
				upNdArr = SPIK_up.helper_list
				
				for k = 1 to SPIK_up.helper_list.count do
				(
					ct = SPIK_up.helper_list[k]
					
					ct.name = "RMCup_"+(k as string)
					hide ct
					freeze ct
					ct.parent = secCtrlPArr[k]
					freezeTM ct mode:#{1..2}
					
					
					
					setUserProp ct "Keep" 0
					setTransformLockFlags ct #{1,2,3,7,8,9}
				)
			)
			
			--fk 控制點
			if(true)then
			(
			/*
			  * 		fk 控制點
			  */ 
			global secFKCtrlPArr = createPntSegs ctrlLine Snake_segs:numsegs  segName:"CSec_FK"
			local _po = secFKCtrlPArr[1].pos
			secFKCtrlPArr[1].pos.controller = position_constraint()
			secFKCtrlPArr[1].pos.controller .appendTarget  secSLCtrlPArr[1] 50
			
			-- 位置繼承是從上一節的旋轉得來
			for c = 2 to secFKCtrlPArr.count do -- c = 2
			(
				local fkc = secFKCtrlPArr[c]
				local newScriptController= position_script()
				fkc.pos.controller = newScriptController
				newScriptController.AddNode "FkParent" secFKCtrlPArr[c-1]
				newScriptController.AddNode "P1" secSLCtrlPArr[c]
				newScriptController.AddNode "P2" secSLCtrlPArr[c-1]
				
				
				local	sscript="
ret = [0,0,0]
if(
		(isvalidnode FkParent) and
		(isvalidnode P1) and
		(isvalidnode P2)
	)				
then
(
	local dist = distance P1.transform.row4 P2.transform.row4
	ret = [1,0,0]*dist*FkParent.transform
)	
ret
"
				newScriptController.script=sscript	
			)
			
			-- 兩層旋轉，基本旋轉來自於 sliding path 上的節點(類似path constraint 的follow)
			-- 第二層，是假設這些點旋轉是從上一層為基礎，一路繼承之前的旋轉得來(我給它們的假parent)
			
			
			for c = 1 to secFKCtrlPArr.count do -- c = 1
			(
				local fkc = secFKCtrlPArr[c]
				fkc.rotation.controller = rotation_List()
				local newScriptController= rotation_script()
				fkc.rotation.controller[1].controller = newScriptController
				fkc.rotation.controller.available.controller = euler_xyz()
				fkc.rotation.controller.setActive 2
				
				caPInfo = attributes pInfo
				(
					parameters Params1
					(
						thisParent	type:#maxObject
					)
				)
				custAttributes.add  newScriptController caPInfo 	
			)
			
			for c = 1 to secFKCtrlPArr.count do -- c = 1
			(
				local thisAttr = custAttributes.get secFKCtrlPArr[c].rotation.controller[1].controller 1 
				if(c > 1)then
					thisAttr.thisParent = (nodeTransformMonitor node:secFKCtrlPArr[c-1] forwardTransformChangeMsgs:false ) 
			)
			
			-- _node = $CSec_FK001_10  tm=rotLocal1
			for c = 1 to secFKCtrlPArr.count-1 do -- c = 1
			(
				local fkc = secFKCtrlPArr[c]
				local newScriptController = fkc.rotation.controller[1].controller
				setUserProp fkc "Keep" 0
				newScriptController.AddNode "P1" secSLCtrlPArr[c]
				newScriptController.AddNode "P2" secSLCtrlPArr[c+1]
				local	sscript="
ret = quat 0 0 0 1

if(::getParentRotmRecurse==undefined)then
(
	global getParentRotmRecurse 
	fn getParentRotmRecurse _node &tm = 
	(
		local rotLocal1 = _node.rotation.controller[2].controller.value
		mat2 = rotLocal1 as matrix3
		tm = mat2 * tm		
		
		local pnode = undefined
		try( pnode = (custAttributes.get _node.rotation.controller[1].controller 1 ).thisParent.node)catch()
		if(isvalidnode pnode )then
		(
			getParentRotmRecurse pnode &tm 
		)
	)
)

local _Parent = undefined
try(_Parent = this.thisParent.node)catch()
if(
		(isvalidnode P1) and
		(isvalidnode P2)
	)				
then
(
	local row1 = normalize (P2.transform.row4 - P1.transform.row4)
	local row2 = normalize ( cross P1.transform.row3 row1 )
	local row3 = normalize ( cross row2 row1	)
	local row2 = normalize ( cross row3 row1	)
	local mat = (matrix3 row1 row2 row3 [0,0,0] )
				
	local rotLocal1 = matrix3 [1,0,0] [0,1,0] [0,0,1] [0,0,0]
	if(isvalidnode _Parent)then
		getParentRotmRecurse _Parent &rotLocal1
	
	ret = (rotLocal1 * mat ).rotationpart
)	
ret
"

				newScriptController.script=sscript	
				
			)
			/*
			  * 		End of Fk 控制點
			  */
			)
			
			-- Blending Bone
			if(true)then
			(
				theblendingBone = CreateBleBoneChain secCtrlPArr
				for k = 1 to theblendingBone.count do
				(
					theblendingBone[k].pos.controller = position_constraint()
					theblendingBone[k].pos.controller.appendTarget  secCtrlPArr[k] 50
					theblendingBone[k].pos.controller.appendTarget  secFKCtrlPArr[k] 0
					setUserProp theblendingBone[k] "Keep" 1
				)
				
				BipHead = (biped.getNode bip #head link:1)
				for m = 1 to (theblendingBone.count-1) do
				(
					theblendingBone[m].frontfin = true
					theblendingBone[m].rotation.controller = LookAt_Constraint()
					theblendingBone[m].rotation.controller.lookat_vector_length = 0.0
					theblendingBone[m].rotation.controller.appendTarget secCtrlPArr[m+1] 50.0
					theblendingBone[m].rotation.controller.appendTarget secFKCtrlPArr[m+1] 0
					
					
					BipHeadNub = BipHead.children[1]
					theblendingBone[m].rotation.controller.pickUpNode = upNdArr [m]
					theblendingBone[m].rotation.controller.upnode_world = false
					theblendingBone[m].rotation.controller.upnode_control = 1
					theblendingBone[m].rotation.controller.StoUP_axis = 1
				)
			)
			
			
			/*
			* 		CA Main
			*/
			caMain = attributes RopeRig_M
			(
				parameters main rollout:p_m
				(
					mctrl	type:#maxObjectTab tabSizeVariable:true
					curvePnt type:#maxObjectTab tabSizeVariable:true
					offset type:#float default:0.0 ui:spnOffset
					bfreeze type:#boolean default:true ui:chkFreeze
				)
				
				rollout p_m "Rope Rig Main"
				(
					dotnetcontrol lbbct "System.Windows.Forms.Label" align:#left
					dotNetControl MList "System.Windows.Forms.ListView" width:140 height:200 
					button btnL "L" align:#left width:40
					button btnR "R" pos:[btnL.pos.x+50,btnL.pos.y] width:40
					button btnF "F" pos:[btnR.pos.x+50,btnR.pos.y] width:40
					checkbutton chkFreeze "Freeze Length" align:#center
					spinner spnOffset "offset:" range:[-1,1,0] scale:0.01 align:#center
					
					
					
					
					fn initListView lv =
					(
						R = dotnetobject "System.Int32" 50
						Colr = dotNetClass "system.drawing.color" 
						
						--lv.backcolor = Colr.green 
						--lv.forecolor = Colr.white 
						
						lv.gridLines = true  
						lv.View = (dotNetClass "System.Windows.Forms.View").Details --#lvwReport  
						lv.MultiSelect =true
						lv.fullRowSelect = true 
						--lv.sorted = false --true 
						lv.LabelEdit=  true
						lv.AllowColumnReorder =false
						--lv.Checkboxes = true 	
						lv.HideSelection = false
						lv.Columns.add "Name" 140
					)
					
					fn timerChangeTextCb_Main =
					(
						if
						(
							(::__p_m != undefined) and
							(::__caMain != undefined)
						)then
						(
							local itm = undefined
							try( itm = __p_m.MList.Items )
							catch()
							if(itm != undefined)then
							(
								for i = 0 to __p_m.MList.Items.count-1 do -- i = 3
								(
									if(__p_m.MList.Items.Item[i].Selected)do
									(
										local nd = __caMain.mctrl[i+1].node
										-- 往前找key，決定上次的KeyType
										local mW1 = at time sliderTime nd.pos.controller.weight[1].controller.value
										if(mW1>0) then --  position script 權重大於0，判定是給左手or右手
										(
											local ct = custAttributes.get nd.pos.controller[1].controller 1
											if(ct.HandWgt>0)then -- lock 右手
											(
												__p_m.lbbct.text = "[Lock]   Right Hand"
												__p_m.lbbct.ForeColor = (dotnetclass "System.Drawing.SystemColors").Control
												__p_m.lbbct.BackColor = (dotnetclass "System.Drawing.Color").Green
											)
											else -- lock 左手
											(
												__p_m.lbbct.text = "[Lock]   Left Hand"
												__p_m.lbbct.ForeColor = (dotnetclass "System.Drawing.SystemColors").Control
												__p_m.lbbct.BackColor = (dotnetclass "System.Drawing.Color").MediumBlue
											)
										)
										else
										(
											__p_m.lbbct.text = "Free"
											__p_m.lbbct.ForeColor = (dotnetclass "System.Drawing.SystemColors").Control
											__p_m.lbbct.BackColor = (dotnetclass "System.Drawing.Color").HotPink 
										)
									)
								)
							)
						)
					)

					on p_m open do
					(
						/*
						  *		全域變數檢查
						  */
						if(true)then
						(
							if(::__p_m == undefined)then
							(
								global __p_m = p_m
							)
							else
								::__p_m = p_m
							
							if(mctrl.count >0)do
							(
								local nd = mctrl[1].node
								local thisAttr = custAttributes.get nd.modifiers[1] 1 
							
								if(thisAttr != undefined)do
								(
									if(::__caMain == undefined)then
										global __caMain = thisAttr
									else
										::__caMain = thisAttr
								)
							)
						)
						
						registerTimeCallback timerChangeTextCb_Main
							
						initListView MList 
						
						local selected = for o in selection collect o
						for n = 1 to mctrl.count do
						(
							local nd = mctrl[n]
							--print nd.node.name
							local bFoundSel =false
							for ob in selected do
							(
								if(nd.node == ob)then
								(
									bFoundSel =true
									exit
								)
							)
							
							itm = dotnetobject "System.Windows.Forms.ListViewItem" nd.node.name
							MList.Items.Add(itm)
							if(bFoundSel)then
								itm.Selected = true
						)
					)
					
					on p_m close do
					(
						unRegisterTimeCallback  timerChangeTextCb_Main
					)
					
					on spnOffset changed val do
					(
						for cur in curvePnt do
						(
							cap = custAttributes.get cur.node.pos.controller.percent.controller 1
							cap.offset = val
						)
					)
					
					on chkFreeze changed state do
					(
						for cur in curvePnt do
						(
							cap = custAttributes.get cur.node.pos.controller.percent.controller 1
							if(state)then
							(
								local curvelen = curvelength cap.refCurve.node
								-- 要把新的FixLen算給他們
								local curPerc = cap.fixedPerc - cap.offset
								local fixLen = curvelen*curPerc
			
								cap.fixedLen = fixLen
							)
							cap.bFixLen = state
						)
					)
					
					on MList DoubleClick arg do
					(
						for i = 0 to MList.Items.count-1 do
						(
							if(MList.Items.Item[i].Selected)do
							(
								select mctrl[i+1].node
							)
						)
					)
					fn setKeyAtPrvTime nd bPrvKey:true = -- nd = $RMC_3
					(
						local roprigCa = custAttributes.get nd.pos.controller[1].controller 1
						addNewKey nd.pos.controller[2].controller sliderTime
						addNewKey nd.pos.controller.weight[1].controller sliderTime
						addNewKey nd.pos.controller.weight[2].controller sliderTime
						addNewKey nd.pos.controller[1].controller.LHandLcP.controller sliderTime
						addNewKey nd.pos.controller[1].controller.RHandLcP.controller sliderTime
						
						if(bPrvKey)then
						(
							-- 往前找key，決定上次的KeyType
							local nmW1 = numKeys nd.pos.controller.weight[1].controller
							if(nmW1 >1)then
							(
								-- 找上一個 key time
								local keyt = getKeyTime nd.pos.controller.weight[1].controller (nmW1 - 1)
								
								local hnwdv_p = at time keyt roprigCa.HandWgt.controller.value
								local keyv_p = at time keyt nd.pos.controller[2].controller.value 
								local keyv_w1 = at time keyt nd.pos.controller.weight[1].controller.value
								local keyv_w2 = at time keyt nd.pos.controller.weight[2].controller.value
									
								local onef = (frameRate / 30.0)*(TicksPerFrame/160.0)
								animate on
								(
									at time (sliderTime -  onef)  roprigCa.HandWgt.controller.value = hnwdv_p
									at time (sliderTime -  onef) nd.pos.controller[2].controller.value = keyv_p 
									at time (sliderTime - onef ) nd.pos.controller.weight[1].controller.value = keyv_w1 
									at time (sliderTime - onef ) nd.pos.controller.weight[2].controller.value = keyv_w2 
								)
								addNewKey roprigCa.HandWgt.controller (sliderTime - onef )
								addNewKey nd.pos.controller[2].controller (sliderTime - onef )
								addNewKey nd.pos.controller.weight[1].controller (sliderTime - onef )
								addNewKey nd.pos.controller.weight[2].controller (sliderTime - onef )
								addNewKey nd.pos.controller[1].controller.LHandLcP.controller (sliderTime - onef )
								addNewKey nd.pos.controller[1].controller.RHandLcP.controller (sliderTime - onef )
							)
						)
					)
					
					on btnL pressed do
					(
						for i = 0 to MList.Items.count-1 do
						(
							if(MList.Items.Item[i].Selected)do
							(
								undo on
								(
									local nd = mctrl[i+1].node -- nd = $RMC_2
									Lhn = nd.pos.controller[1].controller.GetNode "LHandTgt"
									if(isvalidnode Lhn )then
									(										
										local invp = nd.pos * (inverse Lhn.transform)
										local acont = custAttributes.get nd.pos.controller[1].controller 1
										acont.LHandLcP = invp 
										acont.HandWgt = 0
										nd.pos.controller.weight[1] = 100
										nd.pos.controller[2].controller.value = [0,0,0]
										nd.pos.controller.weight[2] = 100
										nd.pos.controller.setActive 2
										
										setKeyAtPrvTime nd
									)
								)
							)
						)
					)
					
					on btnL rightclick do
					(
						for i = 0 to MList.Items.count-1 do
						(
							if(MList.Items.Item[i].Selected)do
							(
								undo on
								(
									local nd = mctrl[i+1].node -- nd = $RMC_3
									Lhn = nd.pos.controller[1].controller.GetNode "LHandTgt"
									if(isvalidnode Lhn )then
									(										
										local acont = custAttributes.get nd.pos.controller[1].controller 1
										acont.LHandLcP = [0,0,0]
										acont.HandWgt = 0
										nd.pos.controller.weight[1] = 100
										nd.pos.controller[2].controller.value = [0,0,0]
										nd.pos.controller.weight[2] = 0
										nd.pos.controller.setActive 1
										
										setKeyAtPrvTime nd bPrvKey:false
									)
								)
							)
						)
					)
					
					on btnR pressed do
					(
						for i = 0 to MList.Items.count-1 do
						(
							if(MList.Items.Item[i].Selected)do
							(
								undo on
								(
									local nd = mctrl[i+1].node -- nd = $RMC_3
									rhn = nd.pos.controller[1].controller.GetNode "RHandTgt"
									if(isvalidnode rhn)then
									(										
										local invp = nd.pos * (inverse rhn.transform)
										local acont = custAttributes.get nd.pos.controller[1].controller 1
										acont.RHandLcP = invp 
										acont.HandWgt = 1.0
										nd.pos.controller.weight[1] = 100
										nd.pos.controller[2].controller.value = [0,0,0]
										nd.pos.controller.weight[2] = 100
										nd.pos.controller.setActive 2
										
										setKeyAtPrvTime nd
									)
								)
							)
						)
					)
					
					on btnR rightclick do
					(
						for i = 0 to MList.Items.count-1 do
						(
							if(MList.Items.Item[i].Selected)do
							(
								undo on
								(
									local nd = mctrl[i+1].node -- nd = $RMC_3
									rhn = nd.pos.controller[1].controller.GetNode "RHandTgt"
									if(isvalidnode rhn)then
									(										
										local acont = custAttributes.get nd.pos.controller[1].controller 1
										acont.RHandLcP = [0,0,0]
										acont.HandWgt = 1.0
										nd.pos.controller.weight[1] = 100
										nd.pos.controller[2].controller.value = [0,0,0]
										nd.pos.controller.weight[2] = 0
										nd.pos.controller.setActive 1
										
										setKeyAtPrvTime nd bPrvKey:false
									)
								)
							)
						)
					)
					
					on btnF pressed do
					(
						for i = 0 to MList.Items.count-1 do
						(
							if(MList.Items.Item[i].Selected)do
							(
								undo on
								(
									local nd = mctrl[i+1].node -- nd = $RMC_3
									local prvPos = nd.pos
									nd.pos.controller.weight[1] = 0
									nd.pos.controller.weight[2] = 100
									nd.pos.controller.setActive 2
									nd.pos = prvPos
									
									setKeyAtPrvTime nd
								)
							)
						)
					)
					
				)
			)	
			
			-- CA Sub
			caSub = attributes RopeRig_S
			(
				parameters sub rollout:p_s
				(
					sctrl			type:#maxObjectTab tabSizeVariable:true
					sctrl_FK		type:#maxObjectTab tabSizeVariable:true
				)
				rollout p_s "Rope Rig Sub"
				(
					-- 清單顯示 IK or FK 
					local bListIKMode=true
					
					
					dotnetcontrol lbbct "System.Windows.Forms.Label" align:#left
					dotNetControl SpringList "System.Windows.Forms.ListView" width:140 height:200 
					button btnL "L" align:#left width:40
					button btnR "R" pos:[btnL.pos.x+50,btnL.pos.y] width:40
					button btnF "F" pos:[btnR.pos.x+50,btnR.pos.y] width:40
					
					button btnS "S" width:40 align:#left 
					button btnFK "FK" pos:[btnS.pos.x+50,btnS.pos.y] width:40
					
					fn initListView lv =
					(
						R = dotnetobject "System.Int32" 50
						Colr = dotNetClass "system.drawing.color" 
						local DotNetColorMan = (dotnetclass "managedservices.cuiupdater").getinstance()
						lv.gridLines = true  
						lv.View = (dotNetClass "System.Windows.Forms.View").Details --#lvwReport  
						lv.MultiSelect =true
						lv.fullRowSelect = true 
						--lv.sorted = false --true 
						lv.LabelEdit=  true
						lv.AllowColumnReorder =false
						--lv.CheckBoxes=true
						lv.HideSelection = false
						lv.backcolor = DotNetColorMan.GetButtonLightShadow()
						lv.forecolor = DotNetColorMan.gettextcolor() 	
						
					)
					
					fn addColumns theLv columnsAr=
					(
						w=(theLv.width/columnsAr.count)-1
						for x in columnsAr do
						(
							theLv.columns.add x w
						)
					)
					
					fn setKeyAtPrvTime nd bPrvKey:False = -- nd = $CSec_10
					(
						addNewKey nd.pos.controller[2].controller sliderTime
						
						addNewKey nd.pos.controller.Position_Constraint.controller[1].controller sliderTime
						addNewKey nd.pos.controller.Position_Constraint.controller[2].controller sliderTime
						addNewKey nd.pos.controller.Position_Constraint.controller[3].controller sliderTime
						
						
						if(bPrvKey)then
						(
							-- 往前找key，決定上次的KeyType
							local nmW1 = numKeys nd.pos.controller.Position_Constraint.controller[1].controller
							if(nmW1 >1)then
							(
								-- 找上一個 key time
								local keyt = getKeyTime nd.pos.controller.Position_Constraint.controller[1].controller (nmW1 - 1)
								
								local keyv_p = at time keyt nd.pos.controller[2].controller.value 
								local keyv_w1 = at time keyt nd.pos.controller.Position_Constraint.controller[1].controller.value
								local keyv_w2 = at time keyt nd.pos.controller.Position_Constraint.controller[2].controller.value
								local keyv_w3 = at time keyt nd.pos.controller.Position_Constraint.controller[3].controller.value
								
								local onef = (frameRate / 30.0)*(TicksPerFrame/160.0)
								animate on
								(
									at time (sliderTime - onef  ) nd.pos.controller[2].controller.value = keyv_p 
									at time (sliderTime - onef  ) nd.pos.controller.Position_Constraint.controller[1].controller.value = keyv_w1 
									at time (sliderTime - onef ) nd.pos.controller.Position_Constraint.controller[2].controller.value = keyv_w2 
									at time (sliderTime - onef  ) nd.pos.controller.Position_Constraint.controller[3].controller.value= keyv_w3
								)
								addNewKey nd.pos.controller[2].controller (sliderTime - onef )
								addNewKey nd.pos.controller.Position_Constraint.controller[1].controller (sliderTime - onef )
								addNewKey nd.pos.controller.Position_Constraint.controller[2].controller (sliderTime - onef )
								addNewKey nd.pos.controller.Position_Constraint.controller[3].controller (sliderTime - onef )
								
							)
						)
						
					)
					
					fn timerChangeTextCb_Sub =
					(
						if
						(
							(::__p_s != undefined) and
							(::__caSub != undefined)
						)then
						(
							local itm = undefined
							try( itm = __p_s.SpringList.Items )
							catch()
							if(itm != undefined)then
							(
								for i = 0 to __p_s.SpringList.Items.count-1 do
								(
									if(__p_s.SpringList.Items.Item[i].Selected)do
									(
										if(__p_s.bListIKMode)then
										(	
											local nd = __caSub.sctrl[i+1].node
											local mWF = at time sliderTime nd.pos.controller.active 
											if(mWF == 1)then
											(
												local mWL = at time sliderTime nd.pos.controller[1].weight[1]
												local mWR = at time sliderTime nd.pos.controller[1].weight[2]
												local mWS = at time sliderTime nd.pos.controller[1].weight[3]
												if(mWS>0)then -- sliding key
												(
													__p_s.lbbct.text = "[Slide Key]"
													__p_s.lbbct.ForeColor = (dotnetclass "System.Drawing.SystemColors").Control
													__p_s.lbbct.BackColor = (dotnetclass "System.Drawing.Color").Olive
												)
												else if (mWR >0)then
												(
													__p_s.lbbct.text = "[Lock]   Right Hand"
													__p_s.lbbct.ForeColor = (dotnetclass "System.Drawing.SystemColors").Control
													__p_s.lbbct.BackColor = (dotnetclass "System.Drawing.Color").Green
												)
												else if (mWL >0)then
												(
													__p_s.lbbct.text = "[Lock]   Left Hand"
													__p_s.lbbct.ForeColor = (dotnetclass "System.Drawing.SystemColors").Control
													__p_s.lbbct.BackColor = (dotnetclass "System.Drawing.Color").MediumBlue
												)	
											)
											else if(mWF == 2)then
											(
												__p_s.lbbct.text = "Free"
												__p_s.lbbct.ForeColor = (dotnetclass "System.Drawing.SystemColors").Control
												__p_s.lbbct.BackColor = (dotnetclass "System.Drawing.Color").HotPink 
											)
										)
										else -- FK
										(
											__p_s.lbbct.text = "FK"
											__p_s.lbbct.ForeColor = (dotnetclass "System.Drawing.SystemColors").Control
											__p_s.lbbct.BackColor = (dotnetclass "System.Drawing.Color").Violet
										)
									)
								)
							)
						)
					)

					fn switchFKIK bFK:True =
					(
						for i = 0 to SpringList.Items.count-1 do
						(
							if(SpringList.Items.Item[i].Selected)do
							(
								--print ( "CALLED" + (i as string) )
								animate on
								(
									local tgtFkNd = sctrl_Fk[i+1].node -- tgtFkNd = $CSec_FK01_6
									local refArr = refs.dependentNodes tgtFkNd
									for nd in refArr do -- nd = refArr[1]  nd = refArr[2]  -- bFK = True
									(
										if(classof nd == bonegeometry)then
										(
											for c = 1 to nd.pos.controller.getNumTargets() do -- c=1  c =2
											(
												local tempNd = nd.pos.controller.getNode c
												if(tempNd == tgtFkNd)then
												(
													if(bFK)then
													(
														for k = 1 to nd.pos.controller.getNumTargets() do 
															nd.pos.controller.setWeight  k 0
														nd.pos.controller.setWeight  c 100	
													)
													else
													(
														for k = 1 to nd.pos.controller.getNumTargets() do 
															nd.pos.controller.setWeight  k 100
														nd.pos.controller.setWeight  c 0	
													)
													addNewKey nd.pos.controller[#Position_Weight_0] sliderTime
													addNewKey nd.pos.controller[#Position_Weight_1] sliderTime
													
												)
											)
											if(classof nd.rotation.controller == lookat_constraint )then
											(
												for c = 1 to nd.rotation.controller.getNumTargets() do
												(
													local tempNd = nd.rotation.controller.getNode c
													if(tempNd == tgtFkNd)then
													(
														if(bFK)then
														(
															for k = 1 to nd.rotation.controller.getNumTargets() do 
																nd.rotation.controller.setWeight  k 0	
															nd.rotation.controller.setWeight  c 100	
														)
														else
														(
															for k = 1 to nd.rotation.controller.getNumTargets() do 
																nd.rotation.controller.setWeight  k 100	
															nd.rotation.controller.setWeight  c 0
														)
														addNewKey nd.rotation.controller[#LookAt_Weight_0] sliderTime
														addNewKey nd.rotation.controller[#LookAt_Weight_1] sliderTime
													)
												)	
											)
										)
									)
									addNewKey tgtFkNd.rotation.controller sliderTime
								)
							)
						)
					)
					
					on p_s open do
					(
						-- global variable registering
						if(true)do
						(
							if(::__p_s == undefined)then
							(
								global __p_s = p_s
							)
							else
								::__p_s = p_s
							
							if(sctrl.count >0)do
							(
								local nd = sctrl[1].node
								local thisAttr = custAttributes.get nd.modifiers[1] 2 
							
								if(thisAttr != undefined)do
								(
									if(::__caSub == undefined)then
										global __caSub = thisAttr
									else
										::__caSub = thisAttr
								)
							)
						)
						
						registerTimeCallback timerChangeTextCb_Sub					
						initListView SpringList 
						addColumns SpringList #("Name")
						
						bListIKMode = true
						-- FK node add to list
						if(true)do
						(
							local srows=#()	
							local selected = for o in selection collect o
							local bFoundSel =false
							for n = 1 to sctrl_fk.count do
							(
								local nd = sctrl_fk[n]
								
								for ob in selected do
								(
									if(nd.node == ob)then
									(
										bFoundSel =true
										exit
									)
								)
							)
							if(bFoundSel)then
							(
								for n = 1 to sctrl_fk.count do
								(
									local nd = sctrl_fk[n]
									local bFoundSel =false
									for ob in selected do
									(
										if(nd.node == ob)then
										(
											bFoundSel =true
											exit
										)
									)
									itm = dotnetobject "System.Windows.Forms.ListViewItem" nd.node.name
									if(bFoundSel)then
									(
										itm.Selected = true
									)
									append srows itm	
								)
								
							)
							
							if(srows.count>0)do
							(
								SpringList.items.addRange srows
								bListIKMode = false
							)
						)

						-- IK node add to list
						if(bListIKMode)do
						(
							local srows=#()	
							local selected = for o in selection collect o
							
							for n = 1 to sctrl.count do
							(
								local nd = sctrl[n]
								local bFoundSel =false
								for ob in selected do
								(
									if(nd.node == ob)then
									(
										bFoundSel =true
										exit
									)
								)
								itm = dotnetobject "System.Windows.Forms.ListViewItem" nd.node.name
								if(bFoundSel)then
								(
									itm.Selected = true
								)
								append srows itm	
							)
								
							if(srows.count>0)do
							(
								SpringList.items.addRange srows
								bListIKMode = true
							)
						)
						
						
						if(bListIKMode)then
						(
							btnL.enabled = true
							btnR.enabled = true
							btnF.enabled = true 
							btnS.enabled = true
							btnFK.enabled = false
						)
						else
						(
							btnL.enabled = false
							btnR.enabled = false
							btnF.enabled = false 
							btnS.enabled = true
							btnFK.enabled = true
						)
					)
					
					on SpringList DoubleClick arg do
					(
						for i = 0 to SpringList.Items.count-1 do
						(
							if(SpringList.Items.Item[i].Selected)do
							(
								if(bListIKMode)then
									select sctrl[i+1].node
								else
									select sctrl_fk[i+1].node
							)
						)
					)
					
					-- Right Click on Listview
					on SpringList mouseDown arg do
					(
						---showproperties arg
						
						if(arg.Button == (dotNetClass ("System.Windows.Forms.MouseButtons")).Right )then
						(
							local hit=(SpringList.HitTest (dotNetObject "System.Drawing.Point" arg.x arg.y))
							global i_t = hit.item
							
							if(bListIKMode)then
							(
								menuSys=
								(
									rcMenu menuBar
									(
										menuItem SelFK "Select FK"
										on SelFK picked do
										(
											for i = 0 to SpringList.Items.count-1 do
											(
												if(SpringList.Items.Item[i] == i_t )do
												(
													select sctrl_Fk[i+1].node
												)
											)
										)
									)
								)
								popUpMenu menuSys rollout:p_s		
							)
							else
							(
								menuSys=
								(
									rcMenu menuBar
									(
										menuItem SelIK "Select IK"
										on SelIK picked do
										(
											for i = 0 to SpringList.Items.count-1 do
											(
												if(SpringList.Items.Item[i] == i_t )do
												(
													select sctrl[i+1].node
												)
											)
										)
									)
								)
								popUpMenu menuSys rollout:p_s		
							)
						)
					)
					
					on btnL pressed do
					(
						for i = 0 to SpringList.Items.count-1 do
						(
							if(SpringList.Items.Item[i].Selected)do
							(
								undo on
								(
									sctrl[i+1].node.pos.controller[2].controller.value =[0,0,0]
									sctrl[i+1].node.pos.controller[1].controller.setWeight  1 100
									sctrl[i+1].node.pos.controller[1].controller.setWeight  2 0
									sctrl[i+1].node.pos.controller[1].controller.setWeight  3 0
									sctrl[i+1].node.pos.controller.setActive 1
									
									setKeyAtPrvTime sctrl[i+1].node bPrvKey:True
								)
							)
						)
					)
					
					on btnR pressed do
					(
						for i = 0 to SpringList.Items.count-1 do
						(
							if(SpringList.Items.Item[i].Selected)do
							(
								undo on
								(
									sctrl[i+1].node.pos.controller[2].controller.value =[0,0,0]
									sctrl[i+1].node.pos.controller[1].controller.setWeight  1 0
									sctrl[i+1].node.pos.controller[1].controller.setWeight  2 100
									sctrl[i+1].node.pos.controller[1].controller.setWeight  3 0
									sctrl[i+1].node.pos.controller.setActive 1
									
									setKeyAtPrvTime sctrl[i+1].node bPrvKey:True
								)
							)
						)
					)
					
					on btnS pressed do
					(
						for i = 0 to SpringList.Items.count-1 do
						(
							if(SpringList.Items.Item[i].Selected)do
							(
								undo on
								(
									
									sctrl[i+1].node.pos.controller[2].controller.value =[0,0,0]
									sctrl[i+1].node.pos.controller[1].controller.setWeight  1 0
									sctrl[i+1].node.pos.controller[1].controller.setWeight  2 0
									sctrl[i+1].node.pos.controller[1].controller.setWeight  3 100
									sctrl[i+1].node.pos.controller.setActive 2
									sctrl[i+1].node.pos.controller[1].controller.value = [0,0,0]
									
									setKeyAtPrvTime sctrl[i+1].node bPrvKey:True
								)
							)
						)
						switchFKIK bFK:False
					)
					
					
					on btnF pressed do
					(
						for i = 0 to SpringList.Items.count-1 do
						(
							if(SpringList.Items.Item[i].Selected)do
							(
								undo on
								(
									local prvPos = sctrl[i+1].node.pos
									sctrl[i+1].node.pos.controller[1].controller.setWeight  1 0
									sctrl[i+1].node.pos.controller[1].controller.setWeight  2 0
									sctrl[i+1].node.pos.controller[1].controller.setWeight  3 0
									sctrl[i+1].node.pos.controller.setActive 2
									sctrl[i+1].node.pos = prvPos
									
									setKeyAtPrvTime sctrl[i+1].node bPrvKey:True
								)
							)
						)
					)
					
					on btnFK pressed do
					(
						switchFKIK bFK:True
						for i = 0 to SpringList.Items.count-1 do
						(
							if(SpringList.Items.Item[i].Selected)do
							(
								undo on
								(
									sctrl[i+1].node.pos.controller[2].controller.value =[0,0,0]
									sctrl[i+1].node.pos.controller[1].controller.setWeight  1 0
									sctrl[i+1].node.pos.controller[1].controller.setWeight  2 0
									sctrl[i+1].node.pos.controller[1].controller.setWeight  3 100
									sctrl[i+1].node.pos.controller.setActive 2
									sctrl[i+1].node.pos.controller[1].controller.value = [0,0,0]
									
									setKeyAtPrvTime sctrl[i+1].node bPrvKey:True
								)
							)
						)
					)
				)
			)	
			
			em = emptymodifier()
			em.name = "Rope_Main"
			
			for k = 1 to SPIK.helper_list.count do
			(
				local nd = SPIK.helper_list[k]
				addmodifier nd em
			)
			
			for k = 1 to secCtrlPArr.count do
			(
				addmodifier secCtrlPArr[k] em
				addmodifier secFKCtrlPArr[k] em
			)
			
			custAttributes.add SPIK.helper_list[1].modifiers[#Rope_Main] caMain
			custAttributes.add SPIK.helper_list[1].modifiers[#Rope_Main] caSub
			local cMain = custAttributes.get SPIK.helper_list[1].modifiers[#Rope_Main] 1
			local cSub = custAttributes.get SPIK.helper_list[1].modifiers[#Rope_Main] 2
			cMain.offset.controller = bezier_float()
			cMain.bfreeze.controller = Boolean_float()
			
			for k = 1 to SPIK.helper_list.count do
				append cMain.mctrl (nodeTransformMonitor node:SPIK.helper_list[k] forwardTransformChangeMsgs:false )
			for k = 1 to secSLCtrlPArr.count do
			(
				append cMain.curvePnt (nodeTransformMonitor node:secSLCtrlPArr[k] forwardTransformChangeMsgs:false )
				local cap = custAttributes.get secSLCtrlPArr[k].pos.controller.percent.controller 1
				--cap.offset.controller = bezier_float()
				--paramwire.connect tradeCop1stPiece.pos.controller[1] tradeSet[n].pos.controller[1] "offset"
				cap.offset.controller = cMain.offset.controller 
				cap.bFixLen.controller =  cMain.bfreeze.controller
			)
			
			
			for k = 1 to secCtrlPArr.count do	
			(
				append cSub.sctrl (nodeTransformMonitor node:secCtrlPArr[k] forwardTransformChangeMsgs:false )
				append cSub.sctrl_FK (nodeTransformMonitor node:secFKCtrlPArr[k] forwardTransformChangeMsgs:false )
			)
			
		)
		
		--MasterCtrlBoneChain = CreateBleBoneChain()
		
		
	)
	
)
createDialog IGS_ChainRope_Gen