unit xc_lib;
interface
  uses windows;
(*******************************************************************************

                        xCore Signature Checker Engine
          -----------------------------------------------------------
                              Автор: BlackCash
                        email: BlackCash2006@Yandex.ru
          -----------------------------------------------------------

*******************************************************************************)
    const
    XC_DLL = 'xCoreLib.dll';

    { TODO : Результат выполнения функции xc_filescan(); }
    XC_CLEAR    = 0;
    XC_VIRUS    = 1;
    XC_ESIZE    = 2;
    XC_EREAD    = 3;
    XC_EMPTY    = 4;

    { TODO : Сообщения движка при инициализации и загрузке баз (отладочные) }
    XC_INIT        = 0;
    XC_INIT_ERROR  = 1;

    XC_LOAD_DB     = 2;
    XC_EREAD_DB    = 3;
    XC_EOPEN_DB    = 4;

    XC_LOAD_PDB    = 5;
    XC_EREAD_PDB   = 6;
    XC_EOPEN_PDB   = 7;
    XC_BUILD_PDB   = 8;

    XC_PARSE_EVN   = 9;
    XC_PARSE_ERR   = 10;
    XC_PARCE_UST   = 11;

    XC_UNARCH_FL   = 31;
    type
    { TODO : Настройки движка (при инициализации настройки устанавливаются поумолчанию) }
    xc_opt_scn  = (xc_scan_html, xc_scan_pdf, xc_scan_graphic, xc_scan_pe,
                   xc_scan_other, xc_unpack_rar, xc_unpack_zip, xc_use_force);

    xc_opts_scn = set of xc_opt_scn;

    { TODO : Главный тип движка }
    pxc_engine       = pointer;

    { TODO : Буфер для сканирования }
    xc_buffer        = array of char;

    { TODO : Индикатор прогресса сканирования файла (0-100%) (-1 при распаковке архивов)}
    pxc_scan_progres = ^xc_scan_progres;
    xc_scan_progres  = procedure(progres: integer);

    { TODO : Вывод отладочных сообщений }
    pxc_dbg_message  = ^xc_dbg_message;
    xc_dbg_message   = procedure(msg: dword; const args: array of const);

    { TODO : Информация о PE файле }
    xc_section = record
        sec_raw_size, sec_raw_offset: integer;
        sec_vir_size, sec_vir_offset: integer;
        sec_flag: integer;
        sec_name, sec_md5: widestring;
    end;

    xc_peinfo = record
        pe_entrypoint,
        pe_seccount: integer;
        pe_size: int64;
        pe_linker, pe_epsection, pe_subsys: widestring;
        pe_firstbytes: array [1..4] of char;
        pe_sections: array of xc_section;
    end;

    (* Инициализация движка *)
    procedure init_engine(var engine: pxc_engine; debug: xc_dbg_message); external XC_DLL;
    (* Деинициализация движка *)
    procedure free_engine(var engine: pxc_engine); external XC_DLL;
    (* Установка настроек сканирования движка (при инициализации настройки устанавливаются поумолчанию) *)
    procedure xc_setoptions(engine: pxc_engine; scanners: xc_opts_scn; maxfsize, maxasize: int64; tempdir: pchar); external XC_DLL;
    (* Добавление сигнатуры в инициализированый движок *)
    procedure xc_readsign(root: pxc_engine; const sign: pchar); external XC_DLL;
    (* Упаковка существующей непакованной БД *)
    procedure xc_packing_db(dbfile: pchar; dbdate: pchar; license: pchar); external XC_DLL;
    (* Загрузка непакованой БД *)
    procedure xc_load_xdb(root: pxc_engine; filename: pchar); external XC_DLL;
    (* Загрузка упакованой БД *)
    procedure xc_load_xpb(root: pxc_engine; filename: pchar); external XC_DLL;
    (* Загрузка всех БД из указаной директории *)
    procedure xc_load_dbdir(engine: pxc_engine; dir: pchar; loadxdb: boolean); external XC_DLL;
    (* Сканирование файла на наличие сигнатуры (результат работы: XC_CLEAR, XC_VIRUS, XC_EREAD, XC_ESIZE) *)
    function xc_matchfile(engine: pxc_engine; filename: pchar; var virname: pchar; progresscall: xc_scan_progres; debugcall: xc_dbg_message; progress: boolean = false): integer; external XC_DLL;
    (* Сканирование буфера (return XC_CLEAR, XC_VIRUS, XC_EREAD, XC_ESIZE) (сканирование без проверки md5)*)
    function xc_scanbuffer(engine: pxc_engine; buffer: xc_buffer; ftype: dword; var virname: pchar): boolean; external XC_DLL;
    (* Кол-во загруженых сигнатур *)
    function xc_sigcount(engine: pxc_engine): integer; external XC_DLL;
    (* Максимальная дата всех загруженых БД *)
    function xc_db_date(engine: pxc_engine): pchar; external XC_DLL;
    (* Наименование движка *)
    function xc_name: pchar; external XC_DLL;
    (* Версия движка *)
    function xc_version: pchar; external XC_DLL;
    (* Перевод строки в 16ти-ричную систему *)
    function xc_str2hex(const str: widestring): widestring; external XC_DLL;
    (* md5 файла *)
    function xc_md5file(const filename: widestring): widestring; external XC_DLL;
    (* md5 строки *)
    function xc_md5string(const str: widestring): widestring; external XC_DLL;
    (* Информация о РЕ файле *)
    function xc_getpeinfo(filename: pchar; var peinfo: xc_peinfo): boolean; external XC_DLL;
    (* Проверка есть ли файл в белой базе *)
    function xc_inwhitelist(engine: pxc_engine; mdhash: pchar; size: integer; var whitename: pchar): boolean; external XC_DLL;
    (* Удаление файла *)
    function xc_deletefile(FileName: pchar) : boolean; external XC_DLL;
    (* Нормализация HTML файлов *)
    function xc_html_exctract(filename: pchar; path: pchar): boolean; external XC_DLL;
    (* Получение НЕХ кода от позиции spos размером в count байт *)
    function xc_getfilehex(filename: widestring; spos, count: integer): widestring; external XC_DLL;
    (* Распаковка упакованной БД *)
    procedure xc_unpack_xdb(filename: pchar); external XC_DLL;
implementation

end.
