# SICRO Operacional v0.1 - Roteiro de Teste Piloto

Este roteiro acompanha a distribuicao interna do APK piloto para peritos.

## Aviso

- Esta e uma versao piloto para teste controlado.
- Os dados ficam somente no aparelho.
- Antes de desinstalar o app ou limpar dados do Android, exporte o pacote `.sicroapp`.
- Nao use como unica fonte de registro oficial durante o piloto.

## Fluxo minimo de validacao

1. Abrir o app e configurar o perfil do perito.
2. Iniciar uma pericia de Transito.
3. Preencher dados basicos do caso.
4. Capturar GPS e salvar a melhor leitura.
5. Capturar pelo menos 3 fotos categorizadas.
6. Responder parte do checklist.
7. Registrar pelo menos 1 veiculo, se aplicavel.
8. Registrar pelo menos 1 vitima/corpo ou marcar como nao aplicavel.
9. Registrar pelo menos 1 vestigio ou marcar como nao aplicavel.
10. Registrar pelo menos 1 medicao ou marcar como nao aplicavel.
11. Criar uma observacao de campo.
12. Exportar o pacote `.sicroapp`.
13. Compartilhar o pacote para outro destino.
14. Fechar e reabrir o app, verificando se a ocorrencia permanece.
15. Excluir uma ocorrencia de teste e confirmar que ela sai da lista.

## Testes por area

### Transito

- Criar ocorrencia de colisao.
- Marcar envolvidos, por exemplo carro x moto ou carro x pedestre.
- Verificar checklist de transito.
- Verificar modulos de veiculos, vitimas, vestigios, medicoes e observacoes.

### Morte violenta

- Criar ocorrencia de morte violenta.
- Selecionar natureza, estado do corpo, quantidade de vitimas, ambiente e vestigios esperados.
- Verificar se o dashboard mostra vitimas/corpos, vestigios biologicos, vestigios balisticos e armas/objetos.
- Verificar checklist de morte violenta.

### Patrimonio

- Criar ocorrencia de patrimonio.
- Testar as naturezas: avaliacao direta, avaliacao indireta, danos, arrombamento e incendio.
- Verificar checklist de patrimonio.
- Verificar fotos, vestigios, medicoes, observacoes e exportacao.

## Feedback esperado

Registrar para cada teste:

- aparelho utilizado;
- tipo de pericia;
- se houve travamento;
- se algum texto ficou confuso;
- se algum campo importante faltou;
- se a exportacao `.sicroapp` foi gerada e compartilhada;
- sugestoes de melhoria para uso real em campo.
