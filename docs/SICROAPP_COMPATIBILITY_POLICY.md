# SICROAPP Compatibility Policy

Politica de compatibilidade entre SICRO Operacional e SICRO Desktop.

Objetivo: impedir que o app mobile e o Desktop saiam de sincronia de forma
silenciosa.

## Regra Principal

No contrato `.sicroapp`:

- Pode adicionar campo opcional.
- Pode adicionar novo JSON opcional.
- Pode adicionar novo valor de catalogo, desde que o Desktop trate como
  desconhecido/exibivel.
- Nao pode renomear campo existente.
- Nao pode remover campo existente.
- Nao pode mudar o tipo de um campo existente.
- Nao pode mover campo de um JSON para outro sem manter copia no lugar antigo.

Se um campo precisar ser renomeado, o campo antigo deve continuar sendo exportado
com o mesmo valor por pelo menos uma versao major completa.

Exemplo correto:

```json
{
  "tecnico_pericial": "Tecnico A",
  "equipe_apoio": "Tecnico A"
}
```

Nesse caso, `equipe_apoio` e alias legado e nao deve ser removido enquanto
Desktop antigo ainda puder ler pacotes novos.

## Versionamento

O campo `manifest.json.versao` segue politica semantica do formato:

| Mudanca | Exemplo | Acao |
| --- | --- | --- |
| Aditiva compativel | Campo opcional novo, JSON opcional novo, catalogo novo | Incrementar minor: `0.1` -> `0.2`. |
| Estabilizacao conjunta | Mobile e Desktop homologados | Promover para `1.0`. |
| Breaking inevitavel | Remocao, renome, mudanca de tipo, mudanca de local | Incrementar major: `1.x` -> `2.0`. |

Regra pratica:

- Nao liberar `1.0` do formato sem Desktop sincronizado.
- Toda mudanca de contrato deve atualizar `SICROAPP_FORMAT_SPEC.md`.
- Toda exportacao nova deve manter `manifest.versao` coerente com o spec.
- `manifest.versoes_compativeis` deve listar versoes antigas lidas de forma
  tolerante pela mesma familia.

## Politica De JSON

Datas:

- Sempre ISO-8601 completo via `DateTime.toIso8601String()`.
- Datas formatadas como `dd/mm/aaaa` sao apenas exibicao de UI.

Campos opcionais:

- Chave ausente significa pacote antigo ou modulo inexistente.
- Chave presente com `null` significa dado nao coletado.
- Chave presente com `""` significa campo textual vazio.

Hashes:

- Hashes sao SHA-256.
- `hashes.json` nao inclui hash de si mesmo.
- O hash deve bater com o conteudo efetivamente gravado no ZIP.

Fotos:

- `fotos.json` e o catalogo de midia.
- Entidades vinculam fotos por ID.
- Caminhos de fotos no pacote sao relativos ao ZIP.

## Novos Tipos De Pericia

Novo tipo de pericia deve seguir o padrao:

```json
{
  "tipo_pericia": "novo_tipo",
  "natureza": "natureza_principal",
  "envolvidos": [],
  "resultado": "nao_informado",
  "resumo": "Novo tipo - Natureza principal",
  "novo_tipo": {
    "campo_especifico": "valor"
  }
}
```

Regras:

- O sub-objeto especifico deve ter o mesmo nome do `tipo_pericia`.
- Campos especificos ficam dentro do sub-objeto.
- Dados transversais continuam nos campos existentes.
- Se houver modulo real, exportar novo JSON opcional e listar em
  `manifest.arquivos`.
- Se o modulo nao existir naquele tipo de pericia, nao inventar arquivo vazio
  obrigatorio.

## Checklist Antes De Mudar O Contrato

Antes de alterar qualquer exportacao `.sicroapp`:

1. A mudanca e aditiva?
2. Algum campo foi renomeado, removido, movido ou teve tipo alterado?
3. O campo antigo precisa ser mantido como alias?
4. `SICROAPP_FORMAT_SPEC.md` foi atualizado?
5. `SicroCampoPackageContract.version` precisa mudar?
6. `manifest.arquivos` lista todos os JSONs gerados?
7. O Desktop deve ignorar esse dado se ainda nao conhecer?
8. Ha teste cobrindo exportacao/importacao tolerante?

Se qualquer resposta indicar risco breaking, alinhar com o SICRO Desktop antes de
implementar.

## Mudancas Ja Registradas

### Formato `0.7`

Mudancas aditivas compativeis:

- `metadados.json.veiculo_oficial`.
- Categoria de checklist `croqui_levantamento`.
- Itens de checklist de transito `metodo_croqui_registrado`,
  `levantamento_drone_realizado` e `croqui_manual_trena`.

Compatibilidade esperada:

- Desktop antigo ignora `veiculo_oficial` se ainda nao conhecer.
- Desktop antigo continua lendo os demais campos de `metadados.json`.
- Itens/categorias novas de checklist devem ser exibidos como dados textuais
  mesmo se o Desktop ainda nao possuir icone ou agrupamento especifico.

### Formato `0.2`

Mudancas aditivas compativeis:

- `caso.json.tecnico_pericial`.
- `caso.json.equipe_policial`.
- `caso.json.comandante_policial`.
- Alias legado preservado: `caso.json.equipe_apoio`.
- `veiculos.json[].ponto_impacto`.
- Novos tipos de vestigio: `derrapagem`, `marca_impacto`.
- Rotulo mais especifico para `sulco`: `Sulcagem/sulco`, mantendo codigo
  `sulco`.
- `manifest.json.versoes_compativeis`.

Compatibilidade esperada:

- Desktop antigo continua lendo `equipe_apoio`.
- Desktop antigo ignora campos novos desconhecidos.
- Desktop antigo pode exibir tipos novos de vestigio como texto/codigo
  desconhecido se ainda nao tiver rotulo proprio.
