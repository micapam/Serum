defmodule Serum.Build.Renderer do
  @moduledoc """
  This module provides functions for rendering pages into complete HTML files.
  """

  alias Serum.Build
  alias Serum.Build.BuildData
  alias Serum.Build.ProjectInfo

  @re_media ~r/(?<type>href|src)="(?:%|%25)media:(?<url>[^"]*)"/
  @re_posts ~r/(?<type>href|src)="(?:%|%25)posts:(?<url>[^"]*)"/
  @re_pages ~r/(?<type>href|src)="(?:%|%25)pages:(?<url>[^"]*)"/

  @spec genpage(String.t, keyword) :: String.t

  def genpage(contents, ctx) do
    base = Serum.Build.BuildData.get "global", "template", "base"
    contents = process_links contents
    binding = [contents: contents, navigation: BuildData.get("global", "navstub")]
    render base, ctx ++ binding
  end

#  @spec render(Build.compiled_template, keyword) :: String.t
#
#  def render(template, context) do
#    {html, _} = Code.eval_quoted template, context
#    html
#  end

  @spec process_links(String.t) :: String.t

  def process_links(text) do
    base = ProjectInfo.get "xxxxx", :base_url
    text = Regex.replace @re_media, text, ~s(\\1="#{base}media/\\2")
    text = Regex.replace @re_posts, text, ~s(\\1="#{base}posts/\\2.html")
    text = Regex.replace @re_pages, text, ~s(\\1="#{base}\\2.html")
    text
  end

  #
  # WORK IN PROGRESS
  #

  @spec genpage(String.t, keyword, pid) :: String.t

  def genpage(contents, ctx, owner) do
    base = Serum.Build.BuildData.get owner, "template", "base"
    contents = process_links contents, owner
    binding = [contents: contents, navigation: BuildData.get(owner, "navstub")]
    render base, ctx ++ binding
  end

  @spec render(Build.compiled_template, keyword) :: String.t

  def render(template, context) do
    {html, _} = Code.eval_quoted template, context
    html
  end

  @spec process_links(String.t, pid) :: String.t

  def process_links(text, owner) do
    base = ProjectInfo.get owner, :base_url
    text = Regex.replace @re_media, text, ~s(\\1="#{base}media/\\2")
    text = Regex.replace @re_posts, text, ~s(\\1="#{base}posts/\\2.html")
    text = Regex.replace @re_pages, text, ~s(\\1="#{base}\\2.html")
    text
  end
end
