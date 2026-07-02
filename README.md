# mri_lixeiro
Sistema de Lixeiro MRIQBOX
# mri_Qgarbage 🗑️

**mri_Qgarbage** é um script completo de Emprego de Lixeiro para servidores FiveM, construído no mesmo modelo do **mri_Qtaxi**, utilizando o framework QBOX Core (`qbx_core`). Traz progressão de níveis (XP), ranqueamento, aluguel/compra de caminhões e rotas dinâmicas de coleta com múltiplas paradas de lixo.

## 🌟 Principais Funcionalidades

* **Progressão e Níveis (XP):** Complete rotas de coleta e ganhe XP. Subir de nível desbloqueia rotas mais longas e lucrativas e aumenta o multiplicador de pagamento.
* **Tablet de Rotas Dinâmico:** Interface moderna onde o jogador visualiza e aceita rotas de coleta em tempo real, com rotação automática de rotas disponíveis no servidor.
* **Rotas com Múltiplas Paradas:** Cada rota sorteia automaticamente várias lixeiras (`Config.Routes[].stopsCount`) dentro da zona escolhida. O jogador precisa visitar parada por parada, pegar o saco de lixo (com animação) e colocá-lo no caminhão.
* **Descarte Final:** Depois de coletar todas as paradas, o jogador leva o caminhão até um ponto de descarte (aterro) configurável para finalizar a rota e receber o pagamento.
* **Aluguel e Compra de Caminhões:** Alugue por tempo (com contador no HUD) ou compre seu próprio caminhão na garagem de coleta.
* **Risco de Perder Carga:** Bater forte com o caminhão carregado pode derrubar sacos de lixo já coletados (perda de eficiência e pagamento) — incentivando direção cuidadosa.
* **Vasculhar Lixeiras Soltas:** Fora das rotas oficiais, o jogador pode vasculhar lixeiras espalhadas pelo mapa (via `ox_target`) com chance de encontrar materiais recicláveis extras.
* **Ranking de Lixeiros:** Veja os jogadores com mais XP/nível/rotas concluídas, com bônus salarial para o Top 3 do servidor.
* **Acesso Remoto via Tablet:** Item `tablet_garbage` usável de qualquer lugar do mapa para abrir o dashboard e aceitar rotas.

## 🛠 Dependências

* [qbx_core](https://github.com/Qbox-project/qbx_core)
* [ox_lib](https://github.com/overextended/ox_lib)
* [ox_target](https://github.com/overextended/ox_target)
* [oxmysql](https://github.com/overextended/oxmysql)
* *(Opcional)* mri_Qcarkeys ou sistema de chaves similar

## 📦 Instalação

1. Coloque a pasta `mri_qgarbage` dentro do seu diretório de `resources`.
2. A tabela `mri_qgarbage_players` é criada automaticamente no banco de dados quando o script inicia (`onResourceStart`), ou rode manualmente o `database.sql`.
3. Adicione `ensure mri_qgarbage` no seu `server.cfg`.
4. Cadastre o item `tablet_garbage` no seu `ox_inventory/data/items.lua`:

```lua
['tablet_garbage'] = {
    label = 'Tablet do Lixeiro',
    weight = 500,
    stack = false,
    close = true,
    description = 'Tablet de acesso remoto à central de rotas de coleta.'
},
```

## ⚙️ Configuração Básica (`config.lua`)

```lua
Config.RouteGenerateInterval = 30 -- Tempo (segundos) para gerar uma nova rota
Config.MaxActiveRoutes       = 15 -- Limite máximo de rotas ativas no tablet

Config.TruckCapacity        = 8    -- Sacos máximos por viagem
Config.SpillChancePerImpact = 0.35 -- Chance de derrubar um saco ao bater forte

-- Cada rota sorteia "stopsCount" paradas dentro de "stopsPool"
Config.Routes = {
    {
        id = 1, label = "Rota Central", zone = "centro",
        stopsPool = {1, 2, 3, 4}, stopsCount = 3,
        basePay = 900, baseXP = 100, minLevel = 1,
    },
    -- ...
}
```

*Desenvolvido com o MRI UI Kit, no mesmo padrão do mri_Qtaxi.*
