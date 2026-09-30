import wave,math,struct,random,pathlib
root=pathlib.Path(__file__).resolve().parent.parent/'assets'
def wav(name,duration,fun):
 sr=22050
 with wave.open(str(root/f'{name}.wav'),'w') as w:
  w.setparams((1,2,sr,0,'NONE','not compressed'));w.writeframes(b''.join(struct.pack('<h',max(-32767,min(32767,int(fun(i/sr)*22000)))) for i in range(int(sr*duration))))
wav('flip',.18,lambda t: math.sin(2*math.pi*(360*t+900*t*t))*math.exp(-18*t)*.5)
wav('star',.26,lambda t: (math.sin(2*math.pi*880*t)+.4*math.sin(2*math.pi*1320*t))*math.exp(-16*t)*.4)
r=random.Random(12)
wav('crash',.35,lambda t:(r.uniform(-1,1)*.3+math.sin(2*math.pi*80*t)*.5)*math.exp(-13*t))
wav('start',.45,lambda t:math.sin(2*math.pi*(440 if t<.15 else 660 if t<.3 else 880)*t)*math.sin(math.pi*t/.45)*.25)
notes=[130.8128,164.8138,195.9977,146.8324,130.8128,164.8138,220,195.9977]
def music(t):
 beat=int(t/.4); local=t%.4
 bass=notes[(beat//4)%8]; mel=[523.25,659.25,783.99,987.77,783.99,659.25,587.33,783.99][beat%8]
 tone=.12*math.sin(2*math.pi*bass*t)+.07*math.sin(2*math.pi*bass*1.5*t)+.12*math.sin(2*math.pi*mel*t)*math.exp(-local*11)+.1*math.sin(2*math.pi*(55*local+20*(1-math.exp(-local*50))))
 return tone*min(1,t*3,(12.8-t)*3)
wav('music',12.8,music)
