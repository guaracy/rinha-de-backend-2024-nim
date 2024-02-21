import std/[strutils, sequtils, times, os]
import mummy, mummy/routers, waterpark/postgres, jsony
#####################################################################################
## DATA DIVISION
#####################################################################################
## LINKAGE SECTION
type Bofh = object
    msg : string
    workaround : string
type Retorno = object
    retorno : int
    msg : string    
type Transacao = object
    valor : int64
    tipo : char
    descricao : string
type ResTransacao = object
    limite:int64
    saldo:int64
type Saldo = object
     total : int64
     data_extrato : string
     limite : int64
type Transacoes = object
    valor : int64
    tipo : string
    descricao : string
    realizada_em : string
type Extrato = object
   saldo : Saldo
   ultimas_transacoes : seq[Transacoes]
#####################################################################################
## WORKING-STORAGE SECTION
const htmlCT = "application/json; charset=utf-8"
let port = parseInt(getEnv("PORT","9999"))
let host = getEnv("DB_HOST","localhost")
let dbPass = getEnv("POSTGRES_PASSWORD","123")
let dbUser = getEnv("POSTGRES_USER","admin")
let dbDatabase = getEnv("POSTGRES_DB","rinha")
var pg : PostgresPool
#####################################################################################
# PROCEDURE DIVISION
#####################################################################################
## Formata erro (application/json)
proc erro(msg:string):string =
  var b:Bofh
  b.msg=msg & "!"
  b.workaround="Call 966666666 - BOFH"
  result = b.toJson
#####################################################################################
## 5 tentativas para conectar com a base de dados
proc tryConnectDB =
  var tentativas = 0
  while tentativas < 5:
    echo port," conectando BD - try ",tentativas
    try:
      pg = newPostgresPool(1, host, dbUser, dbPass, dbDatabase)
      echo port," Conectado!"
      return
    except:
      sleep(2000)
      inc(tentativas)
  echo "** ERRO NA CONEXÃO COM POSTGRESQL **"
  quit(2)
#####################################################################################
## Processa extratos
proc extratoHandler(request: Request) =
  var 
    headers: HttpHeaders
    id = request.pathParams["id"].parseInt
  headers["Content-Type"] = htmlCT
  if id>5:
    request.respond(404,headers,erro("Cliente inexistente"))
  else:
    var 
      e : Extrato
      t : Transacoes
    pg.withConnection conn:
      let linha = conn.getRow(sql"select limite, saldo from clientes where id=?",id)
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
#####################################################################################
## Processa transações
proc movimentacaoConta(id:int,t:Transacao):Retorno =
  pg.withConnection conn:
    conn.exec(sql"START TRANSACTION")
    let linha = conn.getRow(sql"select limite, saldo from clientes where id=? for update",id)
    if allIt(linha, it == ""):
      conn.exec(sql"ROLLBACK")
      result.retorno = 404
    else:
      var r : ResTransacao
      r.limite = linha[0].parseInt
      r.saldo = linha[1].parseInt
      if t.tipo == 'c':
        r.saldo = r.saldo + t.valor
      else:
        r.saldo = r.saldo - t.valor
      if (r.limite + r.saldo) < 0:
        conn.exec(sql"ROLLBACK")
        result.retorno = 422
      else:
        result.retorno = 200
        conn.exec(sql"update clientes set saldo=? where id=?",r.saldo, id)
        conn.exec(sql"COMMIT")
        conn.exec(sql"insert into transacoes (cliente_id,valor,tipo,descricao) values (?,?,?,?)",id,t.valor,t.tipo,t.descricao)
        when not defined(release):    
          echo id,"-T:",t," R:",r
        result.msg=r.toJson
## processa as transações enviadas pela requisição
proc transacoesHandler(request: Request) =
  var 
    headers: HttpHeaders
    id = request.pathParams["id"].parseInt
  headers["Content-Type"] = htmlCT
  var 
    v : Transacao
    s = request.body
  try:
    v = request.body.fromJson(Transacao)
    if v.descricao=="" or v.descricao.len > 10 or v.valor < 1 or not anyIt("cd", it == v.tipo) or id > 5:
      raise
    headers["Content-Type"] = "application/json"
    var r = movimentacaoConta(id,v)
    when not defined(release):    
      echo id,":",request.body," : ",r.msg
    request.respond(r.retorno, headers, r.msg)
  except:
    echo "ERROR : CLI[",id,"] ",request.body
    request.respond(422, headers, erro("JSON incorreto"))  
#####################################################################################
## Main
var router: Router
## Rotas
router.get("/clientes/@id/extrato", extratoHandler)
router.post("/clientes/@id/transacoes", transacoesHandler)
## Start
let server = newServer(router)
tryConnectDB()
echo "Serving on http://localhost:",port
server.serve(Port(port))
## EOF