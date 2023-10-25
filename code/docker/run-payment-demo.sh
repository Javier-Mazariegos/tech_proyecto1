#!/bin/bash

#
# Helper functions
#


# run-in-node: Run a command inside a docker container, using the bash shell
function run-in-node () {
	docker exec "$1" /bin/bash -c "${@:2}"
}

# wait-for-cmd: Run a command repeatedly until it completes/exits successfuly
function wait-for-cmd () {
		until "${@}" > /dev/null 2>&1
		do
			echo -n "."
			sleep 1
		done
		echo
}

# wait-for-node: Run a command repeatedly until it completes successfully, inside a container
# Combining wait-for-cmd and run-in-node
function wait-for-node () {
	wait-for-cmd run-in-node $1 "${@:2}"
}

# carlosalvaradodock/bitcoind-proyecto
# Start the demo
echo "Starting Payment Demo"

echo "======================================================"
echo
echo "Waiting for nodes to startup"
echo -n "- Waiting for bitcoind-proyecto-prueba startup..."
wait-for-node bitcoind-proyecto-prueba "cli getblockchaininfo | jq -e \".blocks > 101\""
echo -n "- Waiting for bitcoind-proyecto-prueba mining..."
wait-for-node bitcoind-proyecto-prueba "cli getbalance | jq -e \". > 50\""
echo -n "- Waiting for Alice startup..."
wait-for-node Alice "cli getinfo"
echo -n "- Waiting for Bob startup..."
wait-for-node Bob "cli getinfo"
echo -n "- Waiting for Chan startup..."
wait-for-node Chan "cli getinfo"
echo -n "- Waiting for Dina startup..."
wait-for-node Dina "cli getinfo"
echo "All nodes have started"

echo "======================================================"
echo

#Aqui se obtienen las llaves publicas de los nodos
#Para hacer manual se puede hacer asi:
  #docker exec -it Alice /bin/bash
  #cli getinfo | jq -r .identity_pubkey
echo "Getting node IDs"
alice_address=$(run-in-node Alice "cli getinfo | jq -r .identity_pubkey")
bob_address=$(run-in-node Bob "cli getinfo | jq -r .identity_pubkey")
chan_address=$(run-in-node Chan "cli getinfo| jq -r .identity_pubkey")
dina_address=$(run-in-node Dina "cli getinfo | jq -r .identity_pubkey")

#Aqui ya es solo para imprimir las llaves publicas-
# Show node IDs
echo "- Alice:  ${alice_address}"
echo "- Bob:    ${bob_address}"
echo "- Chan:   ${chan_address}"
echo "- Dina:	${dina_address}"

echo "======================================================"
echo

#Esto lo que hace es esperar a que todos los nodos se terminen de sincronizar con la blockchain
echo "Waiting for Lightning nodes to sync the blockchain"
echo -n "- Waiting for Alice chain sync..."
wait-for-node Alice "cli getinfo | jq -e \".synced_to_chain == true\""
echo -n "- Waiting for Bob chain sync..."
wait-for-node Bob "cli getinfo | jq -e \".synced_to_chain == true\""
echo -n "- Waiting for Chan chain sync..."
wait-for-node Chan "cli getinfo | jq -e \".synced_to_chain == true\""
echo -n "- Waiting for Dina chain sync..."
wait-for-node Dina "cli getinfo | jq -e \".synced_to_chain == true\""
echo "All nodes synched to chain"

echo "======================================================"
echo

# Creacion de los canales
echo "Setting up connections and channels"


#==================================================== Alice -> BOB =================================================================
echo "- Alice to Bob"

                  #================================== Conexión Alice -> Bob ======================================
run-in-node Alice "cli listpeers | jq -e '.peers[] | select(.pub_key == \"${bob_address}\")' > /dev/null" \
&& {
	echo "- Alice already connected to Bob"
} || {
	echo "- Open connection from Alice node to Bob's node"
	wait-for-node Alice "cli connect ${bob_address}@Bob"
}
                  #================================== Conexión Bob -> Alice ======================================
run-in-node Bob "cli listpeers | jq -e '.peers[] | select(.pub_key == \"${alice_address}\")' > /dev/null" \
&& {
	echo "- Bob already connected to Alice"
} || {
	echo "- Open connection from Bob's node to Alice node"
	wait-for-node Bob "cli connect ${alice_address}@Alice"
}

           #================================== Creación del canal de Alice -> Bob ======================================
run-in-node Alice "cli listchannels | jq -e '.channels[] | select(.remote_pubkey == \"${bob_address}\")' > /dev/null" \
&& {
	echo "- Alice->Bob channel already exists"
} || {
	echo "- Create payment channel Alice->Bob"
	wait-for-node Alice "cli openchannel ${bob_address} 1000000"
}
          #================================== Creación del canal de Bob -> Alice ======================================
run-in-node Bob "cli listchannels | jq -e '.channels[] | select(.remote_pubkey == \"${alice_address}\")' > /dev/null" \
&& {
	echo "- Bob->Alice channel already exists"
} || {
	echo "- Create payment channel Bob->Alice"
	wait-for-node Bob "cli openchannel ${alice_address} 1000000"
}

#====================================================   FIN     ========================================================================



#==================================================== Bob -> Chan =================================================================
echo "Bob to Chan"

              #================================== Conexión Bob -> Chan ======================================
run-in-node Bob "cli listpeers | jq -e '.peers[] | select(.pub_key == \"${chan_address}\")' > /dev/null" \
&& {
	echo "- Bob already connected to Chan"
} || {
	echo "- Open connection from Bob's node to Chan's node"
	wait-for-node Bob "cli connect ${chan_address}@Chan"
}
              #================================== Conexión Chan -> Bob ======================================
run-in-node Chan "cli listpeers | jq -e '.peers[] | select(.pub_key == \"${bob_address}\")' > /dev/null" \
&& {
    echo "- Chan already connected to Bob"
} || {
    echo "- Open connection from Chan's node to Bob's node"
    wait-for-node Chan "cli connect ${bob_address}@Bob"
}


              #================================== Creación del canal de Bob -> Chan ======================================
run-in-node Bob "cli listchannels | jq -e '.channels[] | select(.remote_pubkey == \"${chan_address}\")' > /dev/null" \
&& {
	echo "- Bob->Chan channel already exists"
} || {
	echo "- Create payment channel Bob->Chan"
	wait-for-node Bob "cli openchannel ${chan_address} 1000000"
}

              #================================== Creación del canal de Chan -> Bob ======================================
run-in-node Chan "cli listchannels | jq -e '.channels[] | select(.remote_pubkey == \"${bob_address}\")' > /dev/null" \
&& {
    echo "- Chan->Bob channel already exists"
} || {
    echo "- Create payment channel Chan->Bob"
    wait-for-node Chan "cli openchannel ${bob_address} 1000000"
}
#====================================================   FIN     ========================================================================



#==================================================== Chan -> Dina =================================================================
echo "Chan to Dina"

              #================================== Conexión Chan -> Dina ======================================
run-in-node Chan "cli listpeers | jq -e '.peers[] | select(.pub_key == \"${dina_address}\")' > /dev/null" \
&& {
	echo "- Chan already connected to Dina"
} || {
	echo "- Open connection from Chan's node to Dina's node"
	wait-for-node Chan "cli connect ${dina_address}@Dina"
}

              #================================== Conexión Dina -> Chan ======================================
run-in-node Dina "cli listpeers | jq -e '.peers[] | select(.pub_key == \"${chan_address}\")' > /dev/null" \
&& {
    echo "- Dina already connected to Chan"
} || {
    echo "- Open connection from Dina's node to Chan's node"
    wait-for-node Dina "cli connect ${chan_address}@Chan"
}


              #================================== Creación del canal de Chan -> Dina ======================================
run-in-node Chan "cli listchannels | jq -e '.channels[] | select(.remote_pubkey == \"${dina_address}\")' > /dev/null" \
&& {
	echo "- Chan->Dina channel already exists"
} || {
	echo "- Create payment channel Chan->Dina"
	wait-for-node Chan "cli openchannel ${dina_address} 1000000"
}

              #================================== Creación del canal de Dina -> Chan ======================================
run-in-node Dina "cli listchannels | jq -e '.channels[] | select(.remote_pubkey == \"${chan_address}\")' > /dev/null" \
&& {
    echo "- Dina->Chan channel already exists"
} || {
    echo "- Create payment channel Dina->Chan"
    wait-for-node Dina "cli openchannel ${chan_address} 1000000"
}
#====================================================   FIN     ========================================================================

echo "All channels created"
echo "======================================================"
echo


#Aqui solo se espera para verificar que los canales esten activos
echo "Waiting for channels to be confirmed on the blockchain"
echo -n "- Waiting for Alice channel confirmation..."
wait-for-node Alice "cli listchannels | jq -e '.channels[] | select(.remote_pubkey == \"${bob_address}\" and .active == true)'"
echo "- Alice->Bob connected"
echo -n "- Waiting for Bob channel confirmation..."
wait-for-node Bob "cli listchannels | jq -e '.channels[] | select(.remote_pubkey == \"${alice_address}\" and .active == true)'"
echo "- Bob->Alice connected"
echo -n "- Waiting for Bob channel confirmation..."
wait-for-node Bob "cli listchannels | jq -e '.channels[] | select(.remote_pubkey == \"${chan_address}\" and .active == true)'"
echo "- Bob->Chan connected"
echo -n "- Waiting for Chan channel confirmation..."
wait-for-node Chan "cli listchannels | jq -e '.channels[] | select(.remote_pubkey == \"${bob_address}\" and .active == true)'"
echo "- Chan->Bob connected"
echo -n "- Waiting for Chan channel confirmation..."
wait-for-node Chan "cli listchannels | jq -e '.channels[] | select (.remote_pubkey == \"${dina_address}\" and .active == true)'"
echo "- Chan->Dina connected"
echo -n "- Waiting for Dina channel confirmation..."
wait-for-node Dina "cli listchannels | jq -e '.channels[] | select (.remote_pubkey == \"${chan_address}\" and .active == true)'"
echo "- Dina->Chan connected"
echo "All channels confirmed"



#================================================================= Pago de Alice -> Dina ============================================================

                #===============================================  Verificar ruta Alice -> Dina ========================================
echo "======================================================"
echo -n "Check Alice's route to Dina: "
#Verifica si el nodo de Alice tiene una ruta disponible para enviar un pago de 20,000 a Dina
run-in-node Alice "cli queryroutes --dest \"${dina_address}\" --amt 20000" > /dev/null 2>&1 \
&& {
	echo "Alice has a route to Dina"
} || {
	echo "Alice doesn't yet have a route to Dina"
	echo "Waiting for Alice graph sync. This may take a while..."
	wait-for-node Alice "cli describegraph | jq -e '.edges | select(length >= 1)'"
	echo "- Alice knows about 1 channel"
	wait-for-node Alice "cli describegraph | jq -e '.edges | select(length >= 2)'"
	echo "- Alice knows about 2 channels"
	wait-for-node Alice "cli describegraph | jq -e '.edges | select(length == 3)'"
	echo "- Alice knows about all 3 channels!"
	echo "Alice knows about all the channels"
}
echo "======================================================"
                #===============================================  Genrar factura nodo Dina ========================================
echo "======================================================"
echo
echo "Get 20k sats invoice from Dina"
dina_invoice=$(run-in-node Dina "cli addinvoice 20000 | jq -r .payment_request")
echo "- Dina invoice: "
echo ${dina_invoice}
echo "======================================================"
echo
                #=========================================  Nodo Alice paga la factura de Dina ========================================
echo "Attempting payment from Alice to Dina"
run-in-node Alice "cli payinvoice --json --force ${dina_invoice} | jq -e '.failure_reason == \"FAILURE_REASON_NONE\"'" > /dev/null && {
	echo "Successful payment!"
} ||
{
	echo "Payment failed"
}




#================================================================= Pago de Dina -> Alice ============================================================

                #===============================================  Verificar ruta Dina -> Alice ========================================
echo "======================================================"
echo -n "Check Dina's route to Alice: "
#Verifica si el nodo de Dina tiene una ruta disponible para enviar un pago de 10,000 a Alice
run-in-node Dina "cli queryroutes --dest \"${alice_address}\" --amt 10000" > /dev/null 2>&1 \
&& {
	echo "Dina has a route to Alice"
} || {
	echo "Dina doesn't yet have a route to Alice"
	echo "Waiting for Dina graph sync. This may take a while..."
	wait-for-node Dina "cli describegraph | jq -e '.edges | select(length >= 1)'"
	echo "- Dina knows about 1 channel"
	wait-for-node Dina "cli describegraph | jq -e '.edges | select(length >= 2)'"
	echo "- Dina knows about 2 channels"
	wait-for-node Dina "cli describegraph | jq -e '.edges | select(length == 3)'"
	echo "- Dina knows about all 3 channels!"
	echo "Dina knows about all the channels"
}
echo "======================================================"
                #===============================================  Genrar factura nodo Alice ========================================
echo "======================================================"
echo
echo "Get 10k sats invoice from Alice"
alice_invoice=$(run-in-node Alice "cli addinvoice 10000 | jq -r .payment_request")
echo "- Alice invoice: "
echo ${alice_invoice}
echo "======================================================"
echo
                #=========================================  Nodo Dina paga la factura de Alice ========================================
echo "Attempting payment from Dina to Alice"
run-in-node Dina "cli payinvoice --json --force ${alice_invoice} | jq -e '.failure_reason == \"FAILURE_REASON_NONE\"'" > /dev/null && {
	echo "Successful payment!"
} ||
{
	echo "Payment failed"
}
