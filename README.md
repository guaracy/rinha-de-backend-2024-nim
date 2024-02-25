# Submissão para Rinha de Backend, Segunda Edição: 2024/Q1 - Controle de Concorrência

<img src="https://upload.wikimedia.org/wikipedia/commons/c/c5/Nginx_logo.svg" alt="logo nginx" width="300" height="auto">
<br/><br/>
<img src="https://upload.wikimedia.org/wikipedia/commons/thumb/1/1b/Nim-logo.png/317px-Nim-logo.png" width="200" height="auto" alt="logo nim">
<br/>
<img src="https://upload.wikimedia.org/wikipedia/commons/2/29/Postgresql_elephant.svg" alt="logo postgres" width="200" height="auto">

## Guaracy Monteiro

Submissão feita com:

- `nginx` como load balancer
- `postgres` como banco de dados
- [Nim](https://nim-lang.org/) para api com as libs :
  - [mummy](https://github.com/guzba/mummy) para o servidor
  - [waterpark](https://github.com/guzba/waterpark) para pool de conexões com o BD
  - [jsony](https://github.com/treeform/jsony) para serialização/deserialização de JSON
- [repositório da api](https://github.com/guaracy/rinha-de-backend-2024-nim)

[@guaracybm](https://twitter.com/guaracybm) @ twitter

## Considerações

- A utilização de **Nim** é para sair um pouco do convencional . Uma linguagem compilada com sintaxe semelhante ao Python, pouco utilizada mas que pode ser bem interessante para diversas tarefas. 

- A escolha por **Mummy** se deve a facilidade além de ser relativamente rápido. Não se preocupar com  `{.async.}`, `Future[]` e `await` é muito legal para quem não gosta de lidar com as [cores das funções](https://journal.stuffwithstuff.com/2015/02/01/what-color-is-your-function/). 

- Da mesma forma, **Waterpark** fornece facilidades para trabalhar com um pool de conexões com um BD (MySQL, PostgreSQL e SQlite).

- O **JSONY**, além de ser mais rápido que a implementação original, oferece diversos recursos adicionais com ganchos para popular valores default e qualquer outra coisa que você imaginar.

## Implementação

Apesar de ter sido fornecido um exemplo, achei que tinha muita tabela para algo que apenas pretendia adicionar ou subtrair valores de uma determinada conta e mostrar o saldo. O extrato mostra apenas os últimos 10 lançamentos.

Também retirei todos os procedimentos armazenados no BD. Testar no programa é mais rápido do que enviar para o SGBD, processar e retornar um erro.

Resolvi colocar o saldo juntamente com o limite na tabela de clientes e uma outra tabela para a movimentação (já teria os últimos 10 lançamentos).

Como o ID dos clientes eram de 1-5 (até pediram para não colocar 6 em alguma mensagem), executei o teste diretamente no programa. Evita uma leitura desnecessária no banco de dados.

Considero que as regras para a movimentação estão meio confusas. Poderia retornar erro **422**. se a entrada tivesse um débito que fosse deixar o saldo inconsistente (abaixo do limite da conta) e **400** sempre que o JSON tivesse uma valor incorreto. Mas vamos seguir as regras (até porque ão passaria no teste)

Como não tenho muita familiaridade com o PostrgreSQL, provavelmente as configurações do BD/Memória poderiam ser melhorados.

## Finalmentes

- Para o problema de concorrência no saldo, utilizei `SELECT ... FOR UPDATE` com um `COMMIT` logo após a gravação do saldo para liberar nova leitura da linha. A movimentação e feita logo após, não se preocupando com a concorrência.

- O programa tratou **61503** requisições e todas as respostas foram abaixo de 800ms. Pelos resultados que vi, acredito que a versão em nim não fica devendo muito para outras linguagens também compiladas. Lembrando que Nim utiliza GC e não é possível desabilitar pois a biblioteca mummy utliza GC.

- Os resultados são de uma medição já que elas podem alterar entre uma execução e outra.

- O código não segue nenhuma metodologia da moda. Algumas variáveis são de uma letra só oque não é uma prática muito legal (tirando `i`,`i`,`k` que é uma denominação comum para laços de quem está há um pouco mais de tempo na área) . Em vez de MVC e outras coisas parecidas, como o assunto me lembou bancos e, consequentemente `COBOL`, resolvi fazer um programa monolítico com `DATA DIVISION`, `PROCEDURE DIVISION`, etc.

- `docker-compose up` `docker-compose down` 
