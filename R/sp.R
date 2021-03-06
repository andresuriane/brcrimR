#' Download tables publicized by the São Paulo's Security Office
#'
#'@param year Year to download.
#'@param city Intended city. Is a number between 1 and 645, representing the rank of the city in alphabetical order.
#'@param type Formulary to make the request, encodes the type of information to be downloaded.
#'"ctl00$conteudo$$btnMes" downloads recorded crime count.
#'
#' @export
get_summarized_table_sp <- function(year, city, type = "ctl00$conteudo$btnMensal"){
  url <- 'http://www.ssp.sp.gov.br/Estatistica/Pesquisa.aspx'

  pivot <- httr::GET(url)
  #serve apenas para pegarmos um view_state e um event_validation valido

  states <- get_viewstate(pivot)

  params <- list(`__EVENTTARGET` = type,
                 `__EVENTARGUMENT` = "",
                 `__LASTFOCUS` = "",
                 `__VIEWSTATE` = states$vs,
                 `__EVENTVALIDATION` = states$ev,
                 `ctl00$conteudo$ddlAnos` = year,
                 `ctl00$conteudo$ddlRegioes` = "0",
                 `ctl00$conteudo$ddlMunicipios` = city,
                 `ctl00$conteudo$ddlDelegacias` = "0")

  httr::POST(url, body = params, encode = 'form') %>%
    xml2::read_html() %>%
    rvest::html_table() %>%
    dplyr::first() %>%
    #serve pra pegar apenas a primeira tabela da página, se houver mais do que uma. Estou assumindo que a tabela que eu quero é sempre a primeira.
    dplyr::mutate_at(.funs = parse_number_br, .vars = dplyr::vars(Jan:Total)) %>%
    dplyr::mutate(municipio = city,
                  ano = year)
}

#' Download detailed information publicized by São Paulo's Security Office
#'
#' @param year Year to download.
#' @param month Intended city. Is a number between 1 and 645, representing the rank of the city in alphabetical order.
#' @param type Formulary to make the request, encodes the type of information to be downloaded.
#'
#' @export
get_detailed_table_sp <- function(folder, year, month, department, url = 'http://www.ssp.sp.gov.br/transparenciassp/', helper = T, ...){

  if(helper){
    h <- helper_sp(folder, year, month, department)
  } else {
    h <- list(f = folder, y = year, m = month, d = department)
  }

  httr::GET(url) %>%
    browse(h$f, dest = 'folder') %>%
    browse(h$y, dest = 'year') %>%
    browse(h$m, dest = 'month') %>%
    get_table(h$d, ...) %>%
    open_table()
}

browse <- function(r, val, dest){

  params <- basic_params(val, dest, get_viewstate(r))

  httr::POST(r$url, body = params, encode = 'form', handle = r)
}

get_table <- function(r, department = '0', hdf = "1504014009092", export_header = "ExportarBOLink", ...){

  params <- basic_params(export_header, 'folder', get_viewstate(r)) %>%
    append(list(`ctl00$cphBody$filtroDepartamento` = department,
                `ctl00$cphBody$hdfExport` = hdf))

  httr::POST(r$url, body = params, encode = 'form', handle = r, ...)
}

#' @export
get_historical_detailed_table_sp <- function(f, y, m, d){

  h <- helper_sp(f, y, m, d)

  expand.grid(folder = h$f, year = h$y, month = h$m, department = h$d,
              stringsAsFactors = F) %>%
    as.list() %>%
    purrr::pmap(get_detailed_table_sp, helper = F)
}

#' @export
get_historical_summarized_table_sp <- function(y, c, ty){

  expand.grid(year = y, city = c, type = ty,
              stringsAsFactors = F) %>%
    as.list() %>%
    purrr::pmap_df(get_summarized_table_sp)
}
