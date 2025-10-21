# curriclick
Trabalho semestral da disciplina de Empreendedorismo

## Dataset
Possível dataset: https://www.kaggle.com/datasets/arshkon/linkedin-job-postings

# Curriclick

Para rodar o projeto:

* Instale a linguagem Elixir e o banco de dados PostgreSQL
* Crie um banco de dados chamado `curriclick_dev` e um usuário `postgres` e senha `postgres` para o banco de dados
* Execute o comando `mix setup` para instalar as dependências
* Entre no arquivo assets e execute o comando `npm install`
* Execute o comando `mix ash.codegen --dev`
* Execute o comando `mix ecto.migrate`
* Execute o comando `mix phx.server`

Depois disso, o projeto poderá ser acessado no endereço [`localhost:4000`](http://localhost:4000) pelo navegador

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://hexdocs.pm/phoenix/overview.html
* Docs: https://hexdocs.pm/phoenix
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix
