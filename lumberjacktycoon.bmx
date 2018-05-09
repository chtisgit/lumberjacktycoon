Strict
Framework brl.standardio
Import brl.glmax2d
Import brl.d3d9max2d
Import brl.Graphics
Import brl.timer
Import brl.linkedlist
Import brl.random

AppTitle="Lumberjack Tycoon"

Const BUTPOS=180,DDIV=1200,WORKER_STOP_TIME=DDIV/20
Const BASE_C=4000,BASE_CPD=300,BASE_INIT_MAXW=5
Const WORKER_C=100,WORKER_CPD=30
Const IMPROVE_ADDW=2,IMPROVE_C=1600,IMPROVE_CPD=40
Const DROP_C=200
Const WOOD_C=3

Global game_cb()=Null, init_trees=500, info_text$, time

Function moin(x,y,w,h)
	Local mx=MouseX(),my=MouseY()
	Return mx >= x And my >= y And mx <= x+w And my <= y+h
EndFunction
Function dr(x,y,w,h)
	DrawLine x,y,x+w,y
	DrawLine x,y,x,y+h
	DrawLine x+w,y,x+w,y+h
	DrawLine x,y+h,x+w,y+h
EndFunction

Type Button
	Global list:TList = CreateList()
	Field t$,x,y,w,h,cb()
	Function Add(t$,x,y,cb())
		Local b:Button = New Button
		b.x=x;b.y=y;b.t=t;b.cb=cb
		b.w=TextWidth(t+10)
		b.h=20
		list.addlast b
	EndFunction
	Function UpdateAll()
		Local mhit = MouseHit(MOUSE_LEFT)
		Local cb() = Null
		For Local b:Button = EachIn list
			Local tmp:Byte Ptr = b.Update(mhit)
			If tmp <> Null Then cb = tmp
		Next
		If cb Then cleanup(cb)
	EndFunction
	Method Update:Byte Ptr(mhit)
		Local in = moin(x,y,w,h)
		If in Then SetColor 255,0,0
		dr x,y,w,h
		DrawText t,x+5,y+3
		SetColor 0,0,0
		If mhit And in Then
			Return Byte Ptr cb
		Else
			Return Null
		EndIf
	EndMethod
EndType

Type Tree
	Global list:TList = CreateList()
	Field x,y,wood
	Function AddMany(n)
		For Local i = 1 To n
			Local t:Tree = New Tree
			t.x=Rand(5,GW-10);t.y=Rand(5,GH-60)
			t.wood=Rand(100,200)
			list.addlast t
		Next
	EndFunction
	Function UpdateAll()
		For Local t:Tree = EachIn list
			t.Update
		Next
	EndFunction
	Function Remove(t:Tree)
		list.remove t
	EndFunction
	Method Update()
		DrawLine x,y-5,x,y+5
		SetColor 55+(200-wood)*2,255-(200-wood),80
		DrawOval x-3,y-5,7,6
		SetColor 0,0,0
	EndMethod
	Method in(a,b)
		Return a > x-5 And b > y-5 And a < x+5 And b < y+5
	EndMethod
EndType

Type Base
	Global list:TList = CreateList()
	Field bord_w=100,bord_h=80
	Field x,y,workers:TList,maxw=BASE_INIT_MAXW
	Function draw(x,y,bord_w,bord_h)
		dr x-10,y-5,20,10
		DrawLine x-10,y-6,x,y-10
		DrawLine x,y-10,x+10,y-6
		SetColor 100,100,255
		dr x-bord_w/2,y-bord_h/2,bord_w,bord_h
		SetColor 0,0,0
	EndFunction
	Function drawsh(x,y)
		x:/20;x:*20
		y:/20;y:*20
		If x > 0 And y > 0 And x < GW And y < GH-60 Then
			draw x,y,100,80
			Return 1
		Else
			Return 0
		EndIf
	EndFunction
	Function Add(x,y)
		If Not drawsh(x,y) Then Return
		x:/20;x:*20
		y:/20;y:*20
		Local b:Base = New Base
		b.x=x;b.y=y
		b.workers=CreateList()
		list.addlast b
	EndFunction
	Function Find:Base(x,y)
		Local bx,by
		For Local b:Base = EachIn list
			bx = b.x-b.bord_w/2
			by = b.y-b.bord_h/2
			If x > bx And y > by And x < bx+b.bord_w And y < by+b.bord_h Then Return b 
		Next
		Return Null
	EndFunction
	Function UpdateAll()
		For Local b:Base = EachIn list
			b.Update
		Next
	EndFunction
	Method in(a,b)
		Return a > x-10 And b > y-5 And a < x+10 And b < y+5
	EndMethod
	Method Update()
		draw x,y,bord_w,bord_h
		For Local w:Worker = EachIn workers
			w.Update
		Next
	EndMethod
	Method AddWorker(w:Worker)
		If workers.count() < maxw Then
			workers.addlast w
			Return 1
		Else
			Return 0
		EndIf
	EndMethod
	Method deliver(wood)
		cash :+ wood*WOOD_C
	EndMethod
	Method searchTree:Tree(px,py)
		Local bx,by,dist,best:Tree
		bx = x-bord_w/2
		by = y-bord_h/2
		For Local t:Tree = EachIn Tree.list
			If t.x >= bx And t.y >= by And t.x <= bx+bord_w And t.y <= by+bord_h And t.wood > 0 Then
				Local d=(t.x-px)*(t.x-px)+(t.y-py)*(t.y-py)
				If best = Null Or d < dist Then
					best = t
					dist = d
				EndIf
			EndIf
		Next
		Return best
	EndMethod
	Method improve()
		If maxw >= 25 Then Return 0
		bord_w:+10
		bord_h:+10
		maxw:+IMPROVE_ADDW
		Return 1
	EndMethod
	Function totalCost()
		Local t=0
		For Local b:Base = EachIn list
			t :+ BASE_CPD + IMPROVE_CPD*(b.maxw-BASE_INIT_MAXW)/IMPROVE_ADDW
		Next
		Return t
	EndFunction
EndType

Type Worker
	Global list:TList = CreateList(),freeoc
	Const MAX_WOOD=30
	Field x#,y#,base:Base,tree:Tree,wood,contime
	Function unlinkBase(b:Base)
		For Local w:Worker=EachIn list
			If w.base = b Then
				w.base = Null
				list.remove w
				freeoc:+1
			EndIf
		Next
	EndFunction
	Function unlinkTree(t:Tree)
		For Local w:Worker=EachIn list
			If w.tree = t Then w.tree = Null
		Next
	EndFunction
	Function draw(x,y)
		DrawLine x,y-4,x,y+6
		DrawOval x-2,y-4,5,4
		DrawLine x-3,y+1,x+3,y+1
		DrawLine x,y+6,x-3,y+9
		DrawLine x,y+6,x+3,y+9
	EndFunction
	Function drawsh:Base(x,y)
		Local b:Base = Base.Find(x,y)
		If b And x > 0 And y > 0 And x < GW And y < GH-60 Then
			draw x,y
			Return b
		Else
			Return Null
		EndIf
	EndFunction
	Function Add(base:Base,x,y)
		Local w:Worker = New Worker,r
		w.x=x;w.y=y;w.base=base
		r=base.AddWorker(w)
		If r Then list.addlast w
		Return r
	EndFunction
	Method Update()
		If tree = Null Then
			tree = base.searchTree(x,y)
		EndIf
		
		If contime <= time Then
			Local w#,upd=1
			If wood <> 0 Then
				w = ATan2(base.y-y,base.x-x)
				If base.in(x,y) Then
					base.deliver wood
					wood = 0
					contime = time+WORKER_STOP_TIME
				EndIf
			ElseIf tree <> Null Then
				w = ATan2(tree.y-y,tree.x-x)
				If tree.in(x,y) Then
					wood = Min(tree.wood, MAX_WOOD)
					tree.wood :- wood
					If tree.wood <= 0 Then
						Tree.Remove tree
						UnlinkTree tree
					EndIf
					contime = time+WORKER_STOP_TIME
				EndIf
			Else 
				upd=0
			EndIf
			If upd Then
				x :+ Cos(w)
				y :+ Sin(w)
			EndIf
		
		EndIf
	
		draw x,y
	EndMethod
EndType

Const GW=800,GH=600
Graphics GW,GH

SetClsColor 255,255,255
SetColor 0,0,0

Global cash = 10000, timer:TTimer=CreateTimer(20), day = 1, millionair=0

Button.Add "New Base", BUTPOS, GH-30, NewBase
Button.Add "Hire Lumberjack", BUTPOS+100, GH-30, Hire
Button.Add "Improve Base", BUTPOS+250, GH-30, Improve
Button.Add "Drop Base", BUTPOS+400, GH-30, Drop

Tree.AddMany init_trees

StartScreen

Repeat
	Cls
	Local d = time/DDIV+1
	If d > day Then nextday
	day = d
	
	Base.updateAll
	Tree.updateAll
	
	If game_cb Then game_cb
	
	SetColor 255,255,255
	DrawRect 0,GH-50,GW,50
	If info_text Then
		SetColor 255,0,0
		DrawText info_text, BUTPOS, GH-48
	EndIf
	SetColor 0,0,0
	
	If cash > 1000000 And millionair=0 Then Won
	
	DrawText "Cash: "+cash+"$", 5, GH-30
	DrawText "-/day: -"+totalCost()+"$", 5, GH-15
	DrawText "Day "+day,5,GH-45
	SetColor 0,255,0
	DrawRect 75,GH-41,29*(1.0*(time Mod DDIV)/DDIV),6
	SetColor 0,0,0
	dr 74,GH-42,30,7
	DrawRect 0,GH-50,GW,1
	Button.UpdateAll
	
	Flip 0
	WaitTimer timer
	time :+ 1
Until AppTerminate()
End

Function cleanup(ncb()=Null)
	If ncb<>Null Then info_text=""
	game_cb=ncb
EndFunction

Function totalCost()
	Return Base.totalCost()+Worker.list.count()*WORKER_CPD
EndFunction
Function nextday()
	If Tree.list.count() < 2000 Then Tree.AddMany Rand(5,Min(15*day,600))
	cash :- totalCost()
	If cash < 0 Then Bankrupt
EndFunction

Function NewBase()
	Const COST=BASE_C,CPD=BASE_CPD
	Local mx=MouseX(),my = MouseY()
	
	If cash < COST  Then
		info_text = "Cost: "+COST+"$+"+CPD+"$/day    you can't afford that!"
		cleanup
		Return
	EndIf
	
	info_text = "Cost: "+COST+"$+"+CPD+"$/day    Left click: buy new base, right click: abort"
	If Base.drawsh(mx,my) Then
		If MouseHit(MOUSE_LEFT) Then
			Base.Add mx,my
			cash :- COST
			info_text="Base added!"
			cleanup
		EndIf
	EndIf
	If MouseHit(MOUSE_RIGHT) Then info_text="";cleanup()
EndFunction
Function Hire()
	Const CPD=WORKER_CPD
	Local COST=WORKER_C,mx=MouseX(),my = MouseY()
	
	If Worker.freeoc > 0 Then COST=0
	
	If cash < COST Then
		info_text = "Cost: "+COST+"$+"+CPD+"$/day    you can't afford that!"
		cleanup
		Return
	EndIf
	
	info_text = "Cost: "+COST+"$+"+CPD+"$/day    Left click on a base: hire new worker, right click: abort"
	
	Local base:Base = Worker.drawsh(mx,my)
	If base And MouseHit(MOUSE_LEFT) Then
		If Worker.Add(base,mx,my) Then
			If Worker.freeoc <= 0 Then cash :- COST Else Worker.freeoc:-1
			info_text="Worker added!"
			cleanup
		Else
			info_text="No more workers can be added to this base!"
			cleanup
		EndIf
	EndIf
	If MouseHit(MOUSE_RIGHT) Then info_text="";cleanup()
EndFunction
Function Improve()
	Const COST=IMPROVE_C,CPD=IMPROVE_CPD
	Local mx=MouseX(),my = MouseY()
	
	If cash < COST  Then
		info_text = "Cost: "+COST+"$+"+CPD+"$/day    you can't afford that!"
		cleanup
		Return
	EndIf
	
	info_text = "Cost: "+COST+"$+"+CPD+"$/day    Left click on a base: improve base, right click: abort"
	
	Local base:Base = Base.find(mx,my)
	If base And MouseHit(MOUSE_LEFT) Then
		If base.improve() Then
			cash :- COST
			info_text = "Base improved!"
		Else
			info_text="This base cannot be improved further!"
		EndIf
		cleanup
	EndIf
	If MouseHit(MOUSE_RIGHT) Then info_text="";cleanup()
EndFunction
Function Drop()
	Const COST=DROP_C,CPD=0
	Local mx=MouseX(),my = MouseY()
	
	If cash < COST Then
		info_text = "Cost: "+COST+"$+"+CPD+"$/day    you can't afford that!"
		cleanup
		Return
	EndIf
	
	info_text = "Cost: "+COST+"$+"+CPD+"$/day    Left click on a base: drop base, right click: abort"
	
	Local base:Base = Base.find(mx,my)
	If base And MouseHit(MOUSE_LEFT) Then
		Worker.unlinkBase(base)
		Base.list.remove base
		cash :- COST
		cleanup
	EndIf
	If MouseHit(MOUSE_RIGHT) Then info_text="";cleanup()
EndFunction
Function StartScreen()
	SetScale 2,2
	SetColor 0,0,0
	Repeat
		Cls
		DrawText "Get richer than rich!",50, GH/2-50
		DrawText "Become a self-made millionaire!",50,GH/2-20
		DrawText "Press [Space] to start",50,GH/2+30
		WaitTimer timer
		If AppTerminate() Then End
		Flip 0
	Until KeyHit(KEY_SPACE)
	SetScale 1,1
EndFunction
Function Bankrupt()
	SetScale 2,2
	SetColor 0,0,0
	Repeat
		Cls
		DrawText "You went bankrupt!",50,GH/2-20
		WaitTimer timer
		Flip 0
	Until AppTerminate()
	End
EndFunction
Function Won()
	SetScale 2,2
	SetColor 0,0,0
	Repeat
		Cls
		DrawText "You won the game!",50,GH/2-20
		DrawText "Press [Space] to carry on playing...",50,GH/2+30
		WaitTimer timer
		Flip 0
	Until KeyHit(KEY_SPACE)
	SetScale 1,1
	millionair=1
EndFunction