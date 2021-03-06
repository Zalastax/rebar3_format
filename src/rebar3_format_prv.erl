%%% @doc Plugin provider for rebar3
-module(rebar3_format_prv).

-export([init/1, do/1, format_error/1]).

%% @private
-spec init(rebar_state:t()) -> {ok, rebar_state:t()}.

init(State) ->
    Provider = providers:create([{name, format}, {module, rebar3_format_prv},
                                 {bare, true}, {deps, [app_discovery]},
                                 {example, "rebar3 format [file(s)]"},
                                 {opts,
                                  [{files, $f, "files", string,
                                    "List of files and directories to be formatted"},
                                   {output, $o, "output", string,
                                    "Output directory for the formatted files"}]},
                                 {short_desc, "A rebar plugin for code formatting"}, {desc, ""}]),
    {ok, rebar_state:add_provider(State, Provider)}.

%% @private
-spec do(rebar_state:t()) -> {ok, rebar_state:t()} | {error, string()}.

do(State) ->
    OutputDirOpt = get_output_dir(State),
    Opts = maps:put(output_dir, OutputDirOpt, get_opts(State)),
    rebar_api:debug("Formatter options: ~p", [Opts]),
    Files = get_files(Opts, State),
    rebar_api:debug("Found ~p files: ~p", [length(Files), Files]),
    case format(Files, Opts) of
      ok -> {ok, State};
      {error, Error} -> {error, format_error(Error)}
    end.

%% @private
-spec format_error(any()) -> iolist().

format_error({erl_parse, Error}) ->
    iolist_to_binary(io_lib:format("Formatting error: ~s.Try running with DEBUG=1 for more "
                                   "information",
                                   [Error]));
format_error(Reason) -> io_lib:format("Unknown Formatting Error: ~p", [Reason]).

-spec get_files(rebar3_formatter:opts(),
                rebar_state:t()) -> [file:filename_all()].

get_files(Opts, State) ->
    {Args, _} = rebar_state:command_parsed_args(State),
    Patterns = case lists:keyfind(files, 1, Args) of
                 {files, Wildcard} -> [Wildcard];
                 false ->
                     case Opts of
                       #{files := Wildcards} -> Wildcards;
                       _ -> ["src/**/*.?rl"]
                     end
               end,
    [File || Pattern <- Patterns, File <- filelib:wildcard(Pattern)].

-spec get_output_dir(rebar_state:t()) -> undefined | string().

get_output_dir(State) ->
    {Args, _} = rebar_state:command_parsed_args(State),
    case lists:keyfind(output, 1, Args) of
      {output, OutputDir} -> OutputDir;
      false -> undefined
    end.

-spec get_opts(rebar_state:t()) -> rebar3_formatter:opts().

get_opts(State) -> maps:from_list(rebar_state:get(State, format, [])).

-spec format([file:filename_all()], rebar3_formatter:opts()) -> ok |
                                                                {error, {atom(), string()}}.

format(Files, Opts) ->
    try lists:foreach(fun (File) ->
                              rebar_api:debug("Formatting ~p with ~p", [File, Opts]),
                              rebar3_formatter:format(File, Opts)
                      end,
                      Files)
    catch
      _:{cant_parse, File, {_, erl_parse, Error}} ->
          rebar_api:debug("Couldn't parse ~s: ~p", [File, Error]),
          {error, {erl_parse, Error}};
      _:Error -> rebar_api:debug("Error parsing files: ~p", [Error]), {error, Error}
    end.

