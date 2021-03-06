local mf=math.floor
local rshift, lshift=bit.rshift, bit.lshift
local naturetable={"Hardy","Lonely","Brave","Adamant","Naughty","Bold","Docile","Relaxed","Impish","Lax","Timid","Hasty","Serious","Jolly","Naive","Modest","Mild","Quiet","Bashful","Rash","Calm","Gentle","Sassy","Careful","Quirky"}
local typeorder={"Fighting","Flying","Poison","Ground","Rock","Bug","Ghost","Steel","Fire","Water","Grass","Electric","Psychic","Ice","Dragon","Dark"}

min_HP=28
min_Atk=2
min_Def=28
min_SpA=28
min_SpD=28
min_Spe=28

max_HP=31
max_Atk=31
max_Def=31
max_SpA=31
max_SpD=31
max_Spe=31

searchall=0 -- Search every nature (0 - True | 1 - Search Target Nature Only)
targetnature=3

	  --  // 0 Hardy   1 Lonely   2 Brave    3 Adamant  4 Naughty 
	  --  // 5 Bold    6 Docile   7 Relaxed  8 Impish   9 Lax 
	  --  // 10 Timid  11 Hasty  12 Serious 13 Jolly   14 Naive 
	  --  // 15 Modest 16 Mild   17 Quiet   18 Bashful 19 Rash 
	  --  // 20 Calm   21 Gentle 22 Sassy   23 Careful 24 Quirky 

--List Locks in Reverse order ~ closest to nonshadow first
NatureLocks={0,18,18}
GenderCheck={0,1,1} -- 0 for female, 1 for male, 2 for none
GenderVal={128,192,128} -- Threshold (if F must <; if M must >=)

-- Previous shadow mons before target
previousshadows=0

--Count up the amount of locks that are present
nltotal,go=table.getn(NatureLocks),0

function displayprogress(testHP,testAtk,testDef,testSpA,testSpD,testSpe)
	gui.text(0,0,string.format(" HP: %d",testHP))
	gui.text(0,10,string.format("Atk: %d",testAtk))
	gui.text(0,20,string.format("Def: %d",testDef))
	gui.text(0,30,string.format("SpA: %d",testSpA))
	gui.text(0,40,string.format("SpD: %d",testSpD))
	gui.text(0,50,string.format("Spe: %d",testSpe))
end
function gethiddenpower(testHP,testAtk,testDef,testSpe,testSpA,testSpD)
			hidpowtype=typeorder[1+math.floor(((testHP%2 + 2*(testAtk%2) + 4*(testDef%2) + 8*(testSpe%2) + 16*(testSpA%2) + 32*(testSpD%2))*15)/63)]
			hidpowbase=math.floor(((bit.band(testHP,2)/2 + bit.band(testAtk,2) + 2*bit.band(testDef,2) + 4*bit.band(testSpe,2) + 8*bit.band(testSpA,2) + 16*bit.band(testSpD,2))*40)/63 + 30)
			move=hidpowtype..","..hidpowbase
			return move
end
function nextseed(seed,i)
	for iter=1,i do
	seed=(0x000043FD*(seed%65536)+((0x00000003*(seed%65536)+0x000043FD*mf(seed/65536))%65536)*65536+0x00269EC3)%(4294967296)
	end
	return seed
end
function prevseed(seed,i)
	for iter=1,i do
	seed=(0x00003155*(seed%65536)+((0x0000B9B3*(seed%65536)+0x00003155*mf(seed/65536))%65536)*65536+0xA170F641)%(4294967296)
	end
	return seed
end
function currDir()
  os.execute("cd > cd.tmp")			-- Open up a temporary file
  local f = io.open("cd.tmp", r)	-- Internalize the temp file
  local cwd = f:read("*a")			-- Get Directory
  f:close()							-- Close temp file
  os.remove("cd.tmp")				-- Remove temp file
  return cwd
end
function verifyPID(suckyPID,suckyGen,cl)
	if suckyPID%25==NatureLocks[cl] then
		if GenderCheck[cl]==0 and suckyGen<GenderVal[cl] then
			result=0
		elseif (GenderCheck[cl]==1 and suckyGen>= GenderVal[cl]) then
			result=0
		elseif (GenderCheck[cl]==2) then
			result=0
		end
	else
		result=1
	end
	return result
end
function preparecsvheader()

-- Prepare first row of output
print("")
print("Results will be stored in:  "..currDir().."\\".."LTR "..os.date("%a@%I;%M %p")..".csv")
print("Wait until the window says 'Done Searching' before stopping the script and opening the results file.")
print("")

io.write("Origin Seed,")
io.write("PID,")
io.write("Nature,")
io.write("AntiShinyPID,")
io.write("Anti-Nature,")
io.write("HP,")
io.write("Atk,")
io.write("Def,")
io.write("SpA,")
io.write("SpD,")
io.write("Spe,")
io.write("HP Type,")
io.write("Power,")

if nltotal>0 then	-- If we're calculating with nature locks...
	-- Set up the Nature Lock Output Analysis
	for i=1,nltotal do 
	io.write("Latch"..i..",")
	io.write("Nature"..i..",")
		if i>1 then
		io.write("Fail"..i..",")
		io.write("Started"..i..",")
		io.write("Ended"..i..",")
		end
	end
end

if nltotal==0 then
	io.write("Locked PID,")
	io.write("Nature")
end

io.write("\n")
end
function main()
if go==0 then
go=1

io.output(io.open("LTR "..os.date("%a@%I;%M %p")..".csv","w"))	

preparecsvheader()

	-- Test every IV combination to find a possible origin seed.
	for testHP=min_HP,max_HP do
		for testAtk=min_Atk,max_Atk do
			for testDef=min_Def,max_Def do
				for testSpA=min_SpA,max_SpA do
					for testSpD=min_SpD,max_SpD do
						for testSpe=min_Spe,max_Spe do
						IV1=testHP+testAtk*32+testDef*1024
						IV2=testSpe+testSpA*32+testSpD*1024
						
							for topbit=0,1 do -- check for both instances of the unused topbit
								testIV2=(IV2+32768*topbit)*0x10000
								for lowtrash=0,65535 do
									tempseed=testIV2+lowtrash
									if (rshift(prevseed(tempseed,1),16))%0x8000==IV1 then
										testPID=rshift(nextseed(tempseed,2),16)*0x10000+rshift(nextseed(tempseed,3),16)
										shinyPID=rshift(nextseed(tempseed,4),16)*0x10000+rshift(nextseed(tempseed,5),16)
										testnature=testPID%0x19
										if testnature*searchall==targetnature*searchall then	--if searchall=0, returns true!
										--We have a desired Nature PKM within our IV ranges; need to check nature locks.
										--Find the seed that pre-generates our shadow 'mon
										originseed=prevseed(tempseed,4)
										currentseed=originseed*1
										
										displayprogress(testHP,testAtk,testDef,testSpA,testSpD,testSpe)
											if nltotal>0 then
												if previousshadows~=0 then
														currentseed=prevseed(currentseed,7*previousshadows) -- Unroll past the previous shadow
												end
												
												-- Check to see if the spread satisfies the first NG lock
												preshadow=rshift(prevseed(currentseed,1),16)*0x10000+rshift(currentseed,16)
												
												if (preshadow%25==NatureLocks[1]) then
												-- Passes the Nature Lock
												preshadowgend=preshadow%256											
													if (GenderCheck[1]==0 and preshadowgend<GenderVal[1]) or (GenderCheck[1]==1 and preshadowgend>= GenderVal[1]) or (GenderCheck[1]==2)  then
														-- Passes the Gender Lock
														
														if nltotal>1 then
															currentseed=prevseed(currentseed,5) -- Unroll to the generation seed for the preshadow, so we can check the next nonshadow	
															failedPIDs={0,0,0,0,0}
															startshort={0,0,0,0,0}
															endshort={0,0,0,0,0}
															errors=0										-- Set Up Short checking
															latch={{preshadow,naturetable[preshadow%25+1]},0,0,0,0}
															for cl=2,nltotal do							-- For the rest of the nonshadows, do 
																suckyPID=rshift(prevseed(currentseed,1),16)*0x10000+rshift(currentseed,16)
																suckyGen=suckyPID%256
																
																verizult=verifyPID(suckyPID,suckyGen,cl)

																while verizult==1 do	-- While PID generated isn't valid
																	currentseed=prevseed(currentseed,2)
																	suckyPID=rshift(prevseed(currentseed,1),16)*0x10000+rshift(currentseed,16)
																	suckyGen=suckyPID%256
																	failedPIDs[cl]=failedPIDs[cl]+1
																	verizult=verifyPID(suckyPID,suckyGen,cl)
																end
																
																-- PID Lock Obtained for current criterion. Take note.
																latch[cl]={suckyPID,naturetable[suckyPID%25+1]}
																
																
																-- Checking forward to see if the subsequent lock is shorted.
																if failedPIDs[cl]>0 then 
																
																	failseed=nextseed(currentseed,4)
																	for iter=0,(failedPIDs[cl]-1) do
																		suckyPID=rshift(failseed,16)*0x10000+rshift(nextseed(failseed,1),16)
																		if iter==0 then startshort[cl]=suckyPID end
																		verizult=verifyPID(suckyPID,suckyPID%256,cl-1)
																		
																		failseed=nextseed(failseed,2)
																		if verizult==0 then
																			errors=errors+1
																		end
																	end
																end
																currentseed=prevseed(currentseed,5) -- Unroll for the next preshadow, if any.
																endshort[cl]=suckyPID
															end
															if errors==0 then
															
																-- If no shorting of locks occurs, result is valid. Add entry to table.
																	io.write("=dec2hex("..nextseed(originseed,2).."),")
																	io.write("=dec2hex("..testPID.."),")
																	io.write(naturetable[testnature+1]..",")
																	io.write("=dec2hex("..shinyPID.."),")
																	io.write(naturetable[shinyPID%25+1]..",")
																	io.write(testHP..",")
																	io.write(testAtk..",")
																	io.write(testDef..",")
																	io.write(testSpA..",")
																	io.write(testSpD..",")
																	io.write(testSpe..",")
																	io.write(gethiddenpower(testHP,testAtk,testDef,testSpe,testSpA,testSpD)..",")
																	
																-- Append lock results
																	
																for i=1,nltotal do 
																	io.write("=dec2hex("..latch[i][1].."),")
																	io.write(latch[i][2]..",")
																	
																	if i>1 then
																	-- If the nonshadow occurs directly before the following preshadow lock, null out the table result.
																		if failedPIDs[i]==0 then
																			io.write("None!,")
																			io.write(",")
																			io.write(",")
																		else
																			io.write(failedPIDs[i]..",")
																			io.write("=dec2hex("..startshort[i].."),")
																			io.write("=dec2hex("..endshort[i].."),")
																		end
																	end
																	
																end
																	io.write("\n")
															end
														else
															-- No subsequent locks; spit result
															io.write("=dec2hex("..nextseed(originseed,2).."),")
															io.write("=dec2hex("..testPID.."),")
															io.write(naturetable[testnature+1]..",")
															io.write("=dec2hex("..shinyPID.."),")
															io.write(naturetable[shinyPID%25+1]..",")
															io.write(testHP..",")
															io.write(testAtk..",")
															io.write(testDef..",")
															io.write(testSpA..",")
															io.write(testSpD..",")
															io.write(testSpe..",")
															io.write(gethiddenpower(testHP,testAtk,testDef,testSpe,testSpA,testSpD)..",")
															
															io.write("=dec2hex("..latch[i][1].."),")
															io.write(latch[i][2])
															io.write("\n")
															
															end
														end
													end
											else
											-- No locks at all; spit result
											preshadow=rshift(prevseed(originseed,1),16)*0x10000+rshift(originseed,16)
												
														io.write("=dec2hex("..nextseed(originseed,2).."),")
														io.write("=dec2hex("..testPID.."),")
														io.write(naturetable[testnature+1]..",")
														io.write("=dec2hex("..shinyPID.."),")
														io.write(naturetable[shinyPID%25+1]..",")
														io.write(testHP..",")
														io.write(testAtk..",")
														io.write(testDef..",")
														io.write(testSpA..",")
														io.write(testSpD..",")
														io.write(testSpe..",")
														io.write(gethiddenpower(testHP,testAtk,testDef,testSpe,testSpA,testSpD)..",")
														io.write(string.format("%8X", preshadow)..",")
														io.write(naturetable[preshadow%25+1].."\n")
															
											end
										end
									end
								end
							end
						end
					end
				end
			end
		end
	end
	
	print("Done Searching.")
	io.close()
	go=1
end

end
gui.register(main)