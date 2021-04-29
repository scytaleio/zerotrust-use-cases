# spire_mongo_proxy
This is a demo of using SPIRE and Envoy to authenticate both sides of a MongoDB connection.

The client side is running in a Kind+Kubernetes cluster. The server side is running in a Vagrant VM. The scripts set up both the client and server.

# Diagram
![Arch Diagram](/imgs/arch.png "Architecture diagram").

# Usage
Run the scripts in order:
* 1\_setup\_kube\_cluster.sh
* 2\_setup\_green\_vm.sh

At this point you'll have a working SPIRE setup, with a dummy server running on port 27017 (just a shell script with netcat). The following commands will then set up MongoDB.

* 3\_setup\_mongo\_green\_vm.sh
* 4\_setup\_mongo\_kube\_cluster.sh
* 5\_connect\_mongo.sh

This should give you a MongoDB shell.

Then run:
```
db.runCommand(
   {
      insert: "users",
      documents: [ { _id: 1, user: "abc123", status: "A" } ]
   }
)
```
You should see the result "{ "n" : 1, "ok" : 1 }" to indicate success.

# Troubleshooting
If you see the message: "Unable to connect to the server: x509: certificate is valid for 10.0.0.1, 172.18.0.2, 127.0.0.1, not 0.0.0.0" when running the first script, this is due to a race condition in kind itself. Just re-run the scripts and it will likely work. 
