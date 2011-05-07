%% Copyright (c) 2011, Michael Santos <michael.santos@gmail.com>
%% All rights reserved.
%%
%% Redistribution and use in source and binary forms, with or without
%% modification, are permitted provided that the following conditions
%% are met:
%%
%% Redistributions of source code must retain the above copyright
%% notice, this list of conditions and the following disclaimer.
%%
%% Redistributions in binary form must reproduce the above copyright
%% notice, this list of conditions and the following disclaimer in the
%% documentation and/or other materials provided with the distribution.
%%
%% Neither the name of the author nor the names of its contributors
%% may be used to endorse or promote products derived from this software
%% without specific prior written permission.
%%
%% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
%% "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
%% LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
%% FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
%% COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
%% INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
%% BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
%% LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
%% CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
%% LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
%% ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
%% POSSIBILITY OF SUCH DAMAGE.
-module(verx).
-include("verx.hrl").

-export([start/0, stop/1]).
-export([call/2, call/3]).
-export([
        node_get_info/1,
        domain_get_info/2,
        get_capabilities/1, capabilities/1,
        domain_lookup_by_id/2, domain_lookup_by_name/2, domain_lookup_by_uuid/2,

        domain_create_xml/1, domain_create_xml/2, create/1, create/2,
        list_domains/1, list_domains/2,

        domain_suspend/2, suspend/2,
        domain_resume/2, resume/2,
        domain_destroy/2, destroy/2
    ]).

-define(XML_PATH, "priv/example.xml").


%%-------------------------------------------------------------------------
%%% API
%%-------------------------------------------------------------------------
start() ->
    verx_srv:start().
stop(Ref) ->
    verx_srv:stop(Ref).

call(Ref, Proc) ->
    verx_srv:call(Ref, Proc).
call(Ref, Proc, Arg) ->
    verx_srv:call(Ref, Proc, Arg).

node_get_info(Ref) ->
    verx:call(Ref, node_get_info).

domain_get_info(Ref, Id) ->
    proc(Ref, domain_get_info, Id).

domain_lookup_by_id(Ref, N) when is_integer(N) ->
    verx:call(Ref, domain_lookup_by_id, [
            {int, N}                    % domain id
        ]).

domain_lookup_by_name(Ref, N) when ( is_list(N) orelse is_binary(N) ) ->
    verx:call(Ref, domain_lookup_by_name, [
            {string, N}
        ]).

domain_lookup_by_uuid(Ref, N) when byte_size(N) == 16 ->
    verx:call(Ref, domain_lookup_by_uuid, [
            {remote_uuid, N}
        ]).

capabilities(Ref) ->
    get_capabilities(Ref).
get_capabilities(Ref) ->
    verx:call(Ref, get_capabilities).

create(Ref) ->
    domain_create_xml(Ref).
create(Ref, Path) ->
    domain_create_xml(Ref, Path).

domain_create_xml(Ref) ->
    domain_create_xml(Ref, ?XML_PATH).
domain_create_xml(Ref, Path) ->
    {ok, Bin} = file:read_file(Path),
    verx:call(Ref, domain_create_xml, [
            {remote_nonnull_string, Bin},   % XML
            {int, 0}                        % flags
        ]).

list_domains(Ref) ->
    list_domains(Ref, 10).
list_domains(Ref, N) when is_integer(N) ->
    verx:call(Ref, list_domains, [
            {int, N}                    % number of domains
        ]).

%%
%% Suspend
%%
suspend(Ref, Id) ->
    domain_suspend(Ref, Id).

domain_suspend(Ref, Id) ->
    proc(Ref, domain_suspend, Id).

%%
%% Resume
%%
resume(Ref, Id) ->
    domain_resume(Ref, Id).

domain_resume(Ref, Id) ->
    proc(Ref, domain_resume, Id).

%%
%% Destroy
%%
destroy(Ref, Id) ->
    domain_destroy(Ref, Id).

domain_destroy(Ref, Id) ->
    proc(Ref, domain_destroy, Id).


%%-------------------------------------------------------------------------
%%% Internal functions
%%-------------------------------------------------------------------------
proc(Ref, Proc, Id) ->
    case lookup_domain(Ref, Id) of
        {error, _} = Error ->
            Error;
        Domain ->
            proc_1(Ref, Proc, Domain)
    end.

proc_1(Ref, Proc, Domain) ->
    case verx:call(Ref, Proc, [{remote_domain, Domain}]) of
        {ok, void} -> ok;
        N -> N
    end.

% XXX weak test for UUID, conflicts with 16 byte
% XXX hostnames
lookup_domain(Ref, Domain) when byte_size(Domain) == 16 ->
    case domain_lookup_by_uuid(Ref, Domain) of
        {ok, [{dom, Dom}]} ->
            make_remote_domain(proplists:get_value(uuid, Dom));
        Error ->
            Error
    end;
lookup_domain(Ref, Domain) when ( is_list(Domain) orelse is_binary(Domain) ) ->
    case domain_lookup_by_name(Ref, Domain) of
        {ok, [{dom, Dom}]} ->
            make_remote_domain(proplists:get_value(uuid, Dom));
        Error ->
            Error
    end;
lookup_domain(Ref, Domain) when is_integer(Domain) ->
    case verx:call(Ref, domain_lookup_by_id, [{int, Domain}]) of
        {ok, [{dom, Dom}]} ->
            make_remote_domain(proplists:get_value(uuid, Dom));
        Error ->
            Error
    end.

make_remote_domain(UUID) ->
    [
        {remote_nonnull_string, ""},
        {remote_uuid, UUID},
        {int, 0}
    ].
