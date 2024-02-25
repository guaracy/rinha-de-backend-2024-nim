# Api para a Rinha de Backend - https://github.com/zanfranceschi/rinha-de-backend-2024-q1

import std/[strutils, sequtils, times, os]
import mummy, mummy/routers, waterpark/postgres, jsony

#------------------------------------------------------------------------------------
# DATA DIVISION
#------------------------------------------------------------------------------------

# LINKAGE SECTION
# interface entre a api e JSON

type Retorno = object
    status : int
    msg : string    
# JSON pararequisição de transação
type Transacao = object
    valor : int64
    tipo : char
    descricao : string
# retorno para HTTP 200 OK de transação
type ResTransacao = object
    limite:int64
    saldo:int64
# objeto para retorno de extrato    
type Saldo = object
     total : int64
     data_extrato : string
     limite : int64
# objeto para array para retorno de extrato (últimas transações)
type Transacoes = object
    valor : int64
    tipo : string
    descricao : string
    realizada_em : string
# retornopara HTTP 200 OK de extratos
type Extrato = object
   saldo : Saldo
   ultimas_transacoes : seq[Transacoes]
#------------------------------------------------------------------------------------
# WORKING-STORAGE SECTION
const htmlCTjson = "application/json; charset=utf-8"
var pg : PostgresPool

#------------------------------------------------------------------------------------
# PROCEDURE DIVISION
#------------------------------------------------------------------------------------

# 5 tentativas para conectar com a base de dados
proc tryConnectDB =
  let 
    host = getEnv("DB_HOST","localhost")
    dbPass = getEnv("POSTGRES_PASSWORD","123")
    dbUser = getEnv("POSTGRES_USER","admin")
    dbDatabase = getEnv("POSTGRES_DB","rinha")
  var 
    tentativas = 0
  while tentativas < 5:
    try:
      pg = newPostgresPool(2, host, dbUser, dbPass, dbDatabase)
      return
    except:
      sleep(2000)
      inc(tentativas)
  echo "** ERRO NA CONEXÃO COM POSTGRESQL **"
  quit(2)

#------------------------------------------------------------------------------------
# Processa extratos
proc extratoHandler(request: Request) =
  var 
    headers: HttpHeaders
    id = request.pathParams["id"].parseInt
  headers["Content-Type"] = htmlCTjson
  if id>5:
    request.respond(404,headers,"Cliente inexistente")
  else:
    var 
      e : Extrato
      t : Transacoes
    pg.withConnection conn:
      let 
        linha = conn.getRow(sql"select limite, saldo from clientes where id=?",id)
      e.saldo.limite = linha[0].parseInt
      e.saldo.total = linha[1].parseInt
      e.saldo.data_extrato = $now().utc 
      for linhas in conn.fastRows(sql"select valor,tipo,descricao,realizada_em from transacoes where cliente_id = ? order by realizada_em DESC limit 10",id):
        t.valor = linhas[0].parseInt
        t.tipo = linhas[1]
        t.descricao = linhas[2]
        t.realizada_em = linhas[3]
        e.ultimas_transacoes.add(t)
    when not defined(release):    
      echo id,"-S: " ,e.saldo.toJson()
    request.respond(200, headers, e.toJson)

#------------------------------------------------------------------------------------
# Processa transações
proc movimentacaoConta(id:int,t:Transacao):Retorno =
  pg.withConnection conn:
    conn.exec(sql"START TRANSACTION")
    let 
      linha = conn.getRow(sql"select limite, saldo from clientes where id=? for update",id)
    if allIt(linha, it == ""):
      conn.exec(sql"ROLLBACK")
      result.status = 404
    else:
      var 
        r : ResTransacao
      r.limite = linha[0].parseInt
      r.saldo = linha[1].parseInt
      if t.tipo == 'c':
        r.saldo = r.saldo + t.valor
      else:
        r.saldo = r.saldo - t.valor
      if (r.limite + r.saldo) < 0:
        conn.exec(sql"ROLLBACK")
        result.status = 422
      else:
        result.status = 200
        conn.exec(sql"update clientes set saldo=? where id=?",r.saldo, id)
        conn.exec(sql"COMMIT")
        conn.exec(sql"insert into transacoes (cliente_id,valor,tipo,descricao) values (?,?,?,?)",id,t.valor,t.tipo,t.descricao)
        when not defined(release):    
          echo id,"-T:",t," R:",r
        result.msg=r.toJson
# processa as transações enviadas pela requisição
proc transacoesHandler(request: Request) =
  var 
    headers: HttpHeaders
    id = request.pathParams["id"].parseInt
    v : Transacao
  try:
    v = request.body.fromJson(Transacao)
    if v.descricao=="" or v.descricao.len > 10 or v.valor < 1 or not anyIt("cd", it == v.tipo) or id > 5:
      raise
    headers["Content-Type"] = htmlCTjson
    var 
      r = movimentacaoConta(id,v)
    when not defined(release):    
      echo id,":",request.body," : ",r.msg
    request.respond(r.status, headers, r.msg)
  except:
    when not defined(release):    
      echo "ERROR : CLI[",id,"] ",request.body
    request.respond(422, headers, "JSON incorreto")  
    
#------------------------------------------------------------------------------------
# Main
proc main() =
  let port = parseInt(getEnv("PORT","9999"))
  var router: Router
  router.get("/clientes/@id/extrato", extratoHandler)
  router.post("/clientes/@id/transacoes", transacoesHandler)
  let server = newServer(router)
  tryConnectDB()
  echo "👑 Serving on http://localhost:",port
  server.serve(Port(port))

when isMainModule:
  main()

#------------------------------------------------------------------------------------
# STOP RUN
#------------------------------------------------------------------------------------