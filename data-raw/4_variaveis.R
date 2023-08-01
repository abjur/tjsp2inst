library(magrittr)

files_chunks <- "/mnt/dados/abj/tjsp/" |>
  fs::dir_ls(regexp = "parsed$") |>
  purrr::map(fs::dir_ls) |>
  purrr::flatten_chr()

progressr::with_progress({
  p <- progressr::progressor(length(files_chunks))
  da_cposg <- purrr::map_dfr(files_chunks, ~{
    p()
    purrr::map_dfr(readr::read_rds(.x), "result", .id = "file")
  }, .id = "file_chunk") %>%
    dplyr::mutate(id_processo = basename(fs::path_ext_remove(file))) %>%
    dplyr::distinct(id_processo, .keep_all = TRUE)
})

da_cposg_old <- readr::read_rds("data-raw/da_cposg.rds")
da_cposg <- da_cposg_old |>
  dplyr::bind_rows(da_cposg) |>
  dplyr::distinct(id_processo, .keep_all = TRUE)
readr::write_rds(da_cposg, "data-raw/da_cposg.rds")

## re-download problematic files ----

# progressr::with_progress({
#   p <- progressr::progressor(length(files_chunks))
#   erros <- purrr::map(files_chunks, ~{
#     p()
#     .x %>%
#       readr::read_rds() %>%
#       purrr::map("error") %>%
#       purrr::discard(is.null)
#   }) %>% purrr::flatten()
# })
# length(erros)
# arquivos <- names(erros)
# processos <- basename(fs::path_ext_remove(arquivos))
#
# extra <- purrr::map_chr(
#   processos,
#   lex::tjsp_cposg_download,
#   "/mnt/dados/abj/tjsp/cposg/extra/"
# )
# extra <- fs::dir_ls("/mnt/dados/abj/tjsp/cposg/extra/")
# safe <- purrr::safely(lex::tjsp_cposg_parse)
# res_extra <- purrr::map(extra, safe)
# readr::write_rds(res_extra, "/mnt/dados/abj/tjsp/cposg_parsed/extra.rds")


da_cposg <- readr::read_rds("data-raw/da_cposg.rds")

# id_processo ------------------------------------------------------------
aux_id_processo <- da_cposg %>%
  dplyr::transmute(id_processo)

# info_area -------------------------------------------------------------
aux_info_area <- da_cposg %>%
  dplyr::transmute(
    id_processo,
    info_area = dplyr::case_when(
      area %in% c("Cível", "Criminal") ~ area,
      TRUE ~ NA_character_
    )
  )

# info_classe -----------------------------------------------------------

aux_info_classe <- da_cposg %>%
  dplyr::transmute(
    id_processo,
    info_classe = classe
  )


# info_assunto_full -----------------------------------------------------

aux_info_assunto_full <- da_cposg %>%
  dplyr::transmute(
    id_processo,
    info_assunto_full = assunto
  )


# info_assunto_pai ------------------------------------------------------

aux_info_assunto_pai <- da_cposg %>%
  dplyr::transmute(
    id_processo,
    info_assunto_pai = stringr::str_squish(stringr::str_extract(assunto, "^[^-]+"))
  )


# info_camara_num -------------------------------------------------------

aux_info_camara_num <- da_cposg %>%
  dplyr::transmute(
    id_processo,
    info_camara_num = stringr::str_extract(orgao_julgador, "^[0-9]+"),
    info_camara_num = sprintf("%02d", as.numeric(info_camara_num))
  )

# info_relator ----------------------------------------------------------

aux_info_relator <- da_cposg %>%
  dplyr::transmute(
    id_processo,
    info_relator = abjutils::rm_accent(relator)
  )


# info_comarca ----------------------------------------------------------

arrumar_comarca <- function(x) {
  x_arrumado <- x %>%
    stringr::str_extract("(?<=Comarca de )[^/]+") %>%
    stringr::str_squish() %>%
    stringr::str_to_upper() %>%
    abjutils::rm_accent() %>%
    stringr::str_replace_all("-", " ") %>%
    stringr::str_replace_all("D OESTE", "D'OESTE")

  dplyr::case_when(
    x_arrumado == "ESTRELA D'OESTE" ~ "ESTRELA DOESTE",
    x_arrumado == "CESARIO LANGE" ~ "CESARIO LANGE",
    x_arrumado == "EMBU GUACU" ~ "EMBU-GUACU",
    x_arrumado == "IPAUCU" ~ "IPAUSSU",
    x_arrumado == "PARIQUERA ACU" ~ "PARIQUERA-ACU",
    x_arrumado == "S.P." ~ "SAO PAULO",
    x_arrumado == "FORO DE OUROESTE" ~ "OUROESTE",
    x_arrumado == "SAO LUIZ DO PARAITINGA" ~ "SAO LUIS DO PARAITINGA",
    # OBS: comarca mudou
    x_arrumado == "CESARIO LANGE" ~ "TATUI",
    x_arrumado == "F.D. SALESOPOLIS" ~ "SALESOPOLIS",
    x_arrumado == "SANTANA DO PARNAIBA" ~ "SANTANA DE PARNAIBA",
    x_arrumado == "SANTA SALETE" ~ "URANIA",
    TRUE ~ x_arrumado
  )
}

aux_info_comarca <- da_cposg %>%
  dplyr::transmute(
    id_processo,
    info_comarca = arrumar_comarca(origem)
  )

# # adicionar circunscricao e regiao <<--
# library(sf)
# depara <- abjMaps::d_sf_tjsp$sf$municipio %>%
#   tibble::as_tibble() %>%
#   dplyr::distinct(comarca, circunscricao, regiao)
#
# abjMaps::d_sf_tjsp$sf$municipio %>%
#   tibble::as_tibble() %>%
#   dplyr::select(municipio, comarca, circunscricao, regiao) %>%
#   View()

#
# comarca_nm <- abjMaps::d_sf_tjsp$sf$comarca %>%
#   tibble::as_tibble() %>%
#   dplyr::select(comarca)
#
# aux_info_comarca %>%
#   dplyr::count(comarca = info_comarca) %>%
#   dplyr::anti_join(comarca_nm, "comarca")
#
# comarca_nm %>%
#   dplyr::filter(stringr::str_detect(comarca, "PARAI"))



# info_valor ------------------------------------------------------------

loc <- readr::locale(decimal_mark = ",", grouping_mark = ".")
aux_info_valor <- da_cposg %>%
  dplyr::transmute(
    id_processo,
    info_valor = readr::parse_number(valor_da_acao, locale = loc)
  )


# part_ativo ------------------------------------------------------------
# part_passivo ----------------------------------------------------------
# part_tipo_litigio -----------------------------------------------------

aux_part_unnest <- da_cposg %>%
  dplyr::select(id_processo, partes) %>%
  tidyr::unnest(partes)

# readr::write_rds(aux_part_unnest, "data-raw/aux_part_unnest.rds",
#                  compress = "xz")

ativo <- c(
  "Apelante", "Agravante", "Impetrante",
  "Recorrente", "Autor", "Peticionário",
  "Suscitante", "Reclamante", "ApelanteAMP",
  # "ApteApdo", "ApteApda",
  "Recorrente",
  "Requerente", "Autora", "ImpettePacient",
  "Suscitante", "Suscitado", "Litisconsorte",
  # "ApelanteAMP",
  # "RecteQte",
  "Peticionária",
  "RecteRecdo",
  # "ApteQte", "ApteQdo",
  "Exeqüente"
)

passivo <- c(
  "Apelado", "Agravado", "Apelada",
  "Agravada",
  # "ApdoApte",
  "Paciente",
  # "ApdaApte",
  "Corréu", "Recorrido", "Impetrado", "Recorrida",
  "Réu", "Requerido", "Ré", "Corré", "Reclamado",
  "Requerida", "Querelado", "Impetrada",
  # "ApdoQte",
  "Denunciado"
)

remover <- c(
  "Interessado", "Interessada", "Parte", "Advogado",
  "AssistenteMP", "Advogada", "Interesdo", "Excipiente",
  "Corrigente", "Testemunha", "Perito", "Representante",
  "Excepto", "Corrigido", "DefPúblico", "Representado",
  "Sindicado", "Querelada", "Executado", "RcrdoRcrte",
  "RcrdoQrldo"
)

rx_pj <- stringr::regex(
  pattern = paste(
    "(?<!de) sa$", "ltda", "eirell?i", "associa", "ind[úu]stra",
    "funda[çc]", " me$", "banco", "defensoria", "minist[eé]rio",
    "munic", "estado", "direito", "finan[cç][ai]", "investi",
    "empresa", "transporte", "criminal", "empreend", "seguro",
    "securitizadora", "hospital", "instituto", "inss",
    "estadual", "unimed", "condominio", "eletronic",
    sep = "|"
  ),
  ignore_case = TRUE
)

aux_part_augment <- aux_part_unnest %>%
  dplyr::filter(
    !is.na(parte),
    !is.na(nome),
    !nome %in% c("Sem Advogado", "Juízo Ex Officio"),
    !stringr::str_detect(papel, "Adv")
  ) %>%
  dplyr::mutate(
    polo = dplyr::case_when(
      parte %in% ativo ~ "ativo",
      parte %in% passivo ~ "passivo",
      TRUE ~ "remover"
    ),
    tipo = dplyr::case_when(
      stringr::str_detect(nome, rx_pj) ~ "nPF",
      TRUE ~ "PF"
    )
  ) %>%
  dplyr::filter(polo != "remover")

aux_partes <- aux_part_augment %>%
  dplyr::mutate(nome = ifelse(tipo == "PF", "PESSOA FÍSICA", nome)) %>%
  dplyr::group_by(id_processo, polo) %>%
  dplyr::summarise(
    tipo = dplyr::case_when(
      any(tipo == "nPF") ~ "nPF",
      TRUE ~ "PF"
    ),
    part = paste(nome, collapse = ", "),
    .groups = "drop"
  ) %>%
  tidyr::pivot_wider(
    id_cols = id_processo,
    names_from = c(polo),
    values_from = c(part, tipo)
  ) %>%
  dplyr::filter(
    !is.na(part_passivo),
    !is.na(part_ativo)
  ) %>%
  tidyr::unite(part_tipo_litigio, tipo_ativo, tipo_passivo, sep = "-")


# dec_val ---------------------------------------------------------------
# dec_unanime -----------------------------------------------------------
# dec_date --------------------------------------------------------------

arrumar_decisao <- function(x) {
  rx_negaram <- stringr::regex(
    paste0(
      "negaram|n[aã]o provido|indefe|mantiveram|improcedente|mantid|",
      "rejeit|n[aã]o acolhe|confirmaram|alteraram"
    ),
    ignore_case = TRUE
  )
  rx_parcial <- stringr::regex(
    "parcial|em parte",
    ignore_case = TRUE
  )
  rx_deram <- stringr::regex(
    paste0(
      "deram|provimento|provido|modificaram|revisar|procedente|",
      "adequa|reformou|revis[aã]o|deferiram|retrata|ratific|reformaram"
    ),
    ignore_case = TRUE
  )
  rx_nconhec <- stringr::regex(
    "conhec|prejud|dilig|restitu|extinto|arquivamento|deserto",
    ignore_case = TRUE
  )
  rx_desistiu <- stringr::regex(
    "desist",
    ignore_case = TRUE
  )
  dplyr::case_when(
    stringr::str_detect(x, rx_negaram) ~ "Não reformou",
    stringr::str_detect(x, rx_parcial) ~ "Parcial",
    stringr::str_detect(x, rx_deram) ~ "Reformou",
    stringr::str_detect(x, rx_desistiu) ~ "Desistência",
    stringr::str_detect(x, rx_nconhec) ~ "Não Conheceram / Prejudicado / Diligência",
    TRUE ~ "Outro"
  )
}

arrumar_unanime <- function(x) {
  rx_unanime <- stringr::regex(
    paste(
      " VU([^A-Z]|$)", "V\\. ?U", "unanimidade", "un[âa]nime", "\\(VU\\)",
      sep = "|"
    ),
    ignore_case = TRUE
  )
  rx_maioria <- stringr::regex(
    "maioria|vencid",
    ignore_case = TRUE
  )
  dplyr::case_when(
    stringr::str_detect(x, rx_unanime) ~ "Unânime",
    stringr::str_detect(x, rx_maioria) ~ "Maioria",
    TRUE ~ NA_character_
  )
}

aux_dec_unnest <- da_cposg %>%
  dplyr::select(id_processo, decisoes) %>%
  tidyr::unnest(decisoes)

aux_dec <- aux_dec_unnest %>%
  dplyr::filter(
    decisao != "",
    !stringr::str_detect(decisao, stringr::regex("embargo|cancelam", TRUE)),
<<<<<<< HEAD
    # apenas decisoes a partir de 2020
    lubridate::year(data) >= 2020
=======
    # apenas decisoes de 2021
    lubridate::year(data) == 2021
>>>>>>> d2e9266deb2f2b4421006e8ad1059549bbe5f9ce
  ) %>%
  dplyr::transmute(
    id_processo,
    dec_txt = decisao,
    dec_val = arrumar_decisao(decisao),
    dec_unanime = arrumar_unanime(decisao),
    dec_date = as.Date(data)
  ) %>%
  dplyr::filter(dec_val != "Outro") %>%
  dplyr::arrange(dplyr::desc(dec_date)) %>%
  dplyr::distinct(id_processo, .keep_all = TRUE)

# aux_dec %>%
#   dplyr::mutate(mes = lubridate::floor_date(dec_date, "month")) %>%
#   dplyr::count(mes) %>%
#   print(n = 100)

# time_clean ------------------------------------------------------------

emaux_movs <- da_cposg %>%
  dplyr::select(id_processo, movimentacoes) %>%
  tidyr::unnest(movimentacoes)

aux_tempo <- aux_movs %>%
  dplyr::transmute(
    id_processo,
    data = lubridate::dmy(data)
  ) %>%
  dplyr::filter(data > "1970-01-01") %>%
  dplyr::arrange(data) %>%
  dplyr::distinct(id_processo, .keep_all = TRUE) %>%
  dplyr::inner_join(aux_dec, "id_processo") %>%
  dplyr::mutate(tempo = as.integer(dec_date - data)) %>%
  dplyr::filter(tempo > 0) %>%
  dplyr::select(id_processo, tempo)


# join --------------------------------------------------------------------

da_boletim_full <- aux_id_processo %>%
  dplyr::inner_join(aux_info_area, "id_processo") %>%
  dplyr::inner_join(aux_info_classe, "id_processo") %>%
  dplyr::inner_join(aux_info_assunto_full, "id_processo") %>%
  dplyr::inner_join(aux_info_assunto_pai, "id_processo") %>%
  dplyr::inner_join(aux_info_camara_num, "id_processo") %>%
  dplyr::inner_join(aux_info_relator, "id_processo") %>%
  dplyr::inner_join(aux_info_comarca, "id_processo") %>%
  dplyr::inner_join(aux_info_valor, "id_processo") %>%
  dplyr::inner_join(aux_partes, "id_processo") %>%
  dplyr::inner_join(aux_dec, "id_processo") %>%
  dplyr::inner_join(aux_tempo, "id_processo") %>%
  dplyr::mutate(
    dplyr::across(where(is.character), tidyr::replace_na, "(Vazio)"),
    dplyr::across(
      where(~!any(lubridate::is.Date(.x)) & length(unique(.x)) < 1000), as.factor
    )
  ) %>%
  dplyr::filter(info_area != "(Vazio)")

casos_retirados <- aux_id_processo %>%
  dplyr::anti_join(da_boletim, "id_processo")

readr::write_rds(casos_retirados, "data-raw/casos_retirados.rds", compress = "xz")
readr::write_rds(da_boletim_full, "data-raw/da_boletim_full.rds", compress = "xz")



# export ------------------------------------------------------------------

dplyr::glimpse(da_boletim)
da_boletim_full <- readr::read_rds("data-raw/da_boletim.rds")

tjsp2inst <- da_boletim_full %>%
<<<<<<< HEAD
  dplyr::mutate(tempo = as.integer(tempo))
=======
  dplyr::select(-dec_txt) %>%
  dplyr::bind_rows(tjsp2inst::tjsp2inst) %>%
  dplyr::distinct(id_processo, .keep_all = TRUE)

tjsp2inst <- tjsp2inst %>%
  dplyr::mutate(dec_ano = as.factor(lubridate::year(dec_date))) %>%
  dplyr::filter(
    !info_area %in% "(Vazio)",
    dec_ano %in% c("2020", "2021")
  )
>>>>>>> d2e9266deb2f2b4421006e8ad1059549bbe5f9ce

usethis::use_data(tjsp2inst, overwrite = TRUE)


