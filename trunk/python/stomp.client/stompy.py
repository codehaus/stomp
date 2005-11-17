from socket import *

class Connection:
	global sock,HostName,PortNo,TextBuf
	TextBuf = 2048
	sock = socket(AF_INET,SOCK_STREAM)		
	PortNo = 61613 #port number for STOMP messages
	HostName = 'localhost' #name / ip of host.
	
	def init (self,login, passcode, HOST=HostName, PORT=PortNo):
		sock.connect ((HOST, PORT))
		self.transmit ("CONNECT",{'login':login,'passcode':passcode})
		self.receive() #this sweeps the 'CONNECTED...' message from the broker
		
	def begin (self,headers={}):
		self.transmit ("BEGIN", headers={})
		
	def commit (self,headers={}):
		self.transmit ("COMMIT", headers={})
		
	def abort (self,headers={}):
		self.transmit ("ABORT", headers={})
		
	def subscribe (self,name,headers={}):
		headers['destination'] = name
		self.transmit ("SUBSCRIBE",headers)
		return self.receive()	
		
	def unsubscribe (self,name,headers={}):
		headers['destination'] = name
		self.transmit ("UNSUBSCRIBE", headers)
		
	def send (self,destination, message, headers={}):
		headers['destination']=destination
		self.transmit ("SEND", headers, message)
		
	def disconnect (self,headers={}):
		self.transmit ("DISCONNECT", headers)
		
	def transmit (self,command, headers={}, body=''):
		sock.send ("%s\r" % (command))
		for k,v in headers.items():
			sock.send ("%s:%s\r" % (k,v)) 
		sock.send ("\r")
		sock.send ("%s\r" %(body))
		sock.send ("\x00\r")
			
	def receive(self):
		MsgList = []
		Data = ''
		
		#some clients may produce a hanging new line.
		while ((Data.endswith("\x00")==False)&(Data.endswith("\x00",0,len(Data)-1)==False)):
			Data = Data + sock.recv(TextBuf)
						
		Msgs=Data.split("MESSAGE\n") #seperate messages into a list
		for Msg in Msgs[1:]:
			headflag = True
			headtemp = {}
			body = ''
			lines=Msg.split('\n') #split each message element by \n
			for line in lines:
				if (line == ''):
					headflag=False  #no more headers exist
				elif (line != '\x00'):
					if (headflag==True):
						headparts = line.split(":",1)
						headtemp[headparts[0]]=headparts[1]
					else:
						if (body != ''):
							body=body+"\n"
						body=body+line
			#create the message
			m = Message()
			m.init('MESSAGE',headtemp,body) #at present only MESSAGE commands are supported.
			MsgList.append(m)
		return MsgList
		
class Message:
	headers={}
	body=""
	command=""
	
	def init(self,cmd,hds,bdy):
		self.headers=hds
		self.body=bdy
		self.command=cmd
