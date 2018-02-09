defmodule ChangelogWeb.NewsItemView do
  use ChangelogWeb, :public_view

  alias Changelog.{Files, Hashid, NewsAd, NewsItem, Regexp}
  alias ChangelogWeb.{Endpoint, NewsAdView, NewsSourceView, EpisodeView, PersonView, TopicView, PodcastView}

  def admin_edit_link(conn, user, item) do
    if user && user.admin do
      link("[Edit]", to: admin_news_item_path(conn, :edit, item, next: current_path(conn)), data: [turbolinks: false])
    end
  end

  def image_link(item, version \\ :large) do
    if item.image do
      content_tag :div, class: "news_item-image" do
        link to: item.url do
          tag :img, src: image_url(item, version), alt: item.headline
        end
      end
    end
  end

  def image_path(item, version) do
    {item.image, item}
    |> Files.Image.url(version)
    |> String.replace_leading("/priv", "")
  end

  def image_url(item, version) do
    static_url(Endpoint, image_path(item, version))
  end

  def items_with_ads(items, []), do: items
  def items_with_ads(items, ads) do
    items
    |> List.insert_at(3, Enum.at(ads, 0))
    |> List.insert_at(9, Enum.at(ads, 1))
    |> Enum.reject(&is_nil/1)
  end

  def permalink_path(conn, item) do
    if item.object_id, do: dev_relative(item.url), else: news_item_path(conn, :show, slug(item))
  end

  def permalink_data(item) do
    if item.object_id, do: [news: true], else: []
  end

  def render_item_summary_or_ad(item = %NewsItem{}, assigns), do: render("_summary.html", Map.merge(assigns, %{item: item, style: "relative"}))
  def render_item_summary_or_ad(ad = %NewsAd{}, assigns), do: render(NewsAdView, "_summary.html", Map.merge(assigns, %{ad: ad, sponsor: ad.sponsor}))

  def render_item_source_image(conn, item = %{type: :audio, object: episode}) when is_map(episode) do
    render("source/_image_episode.html", conn: conn, item: item, episode: episode)
  end
  def render_item_source_image(conn, item) do
    cond do
      item.author -> render("source/_image_author.html", conn: conn, item: item, author: item.author)
      item.source && item.source.icon -> render("source/_image_source.html", conn: conn, item: item, source: item.source)
      topic = Enum.find(item.topics, &(&1.icon)) -> render("source/_image_topic.html", conn: conn, item: item, topic: topic)
      true -> render("source/_image_fallback.html", conn: conn, item: item)
    end
  end

  # same as `render_item_source_image` except the cascade is re-ordered
  def render_item_source_name(conn, item = %{type: :audio, object: episode}) when is_map(episode) do
    render("source/_name_episode.html", conn: conn, item: item, episode: episode)
  end
  def render_item_source_name(conn, item) do
    cond do
      item.source && item.source.icon -> render("source/_name_source.html", conn: conn, item: item, source: item.source)
      item.author -> render("source/_name_author.html", conn: conn, item: item, author: item.author)
      true -> render("source/_name_fallback.html", conn: conn, item: item)
    end
  end

  def render_item_title(conn, item) do
    if item.object_id do
      render("title/_internal.html", conn: conn, item: item)
    else
      render("title/_external.html", conn: conn, item: item)
    end
  end

  def render_item_toolbar_button(conn, item) do
    cond do
      NewsItem.is_audio(item) && item.object -> render("toolbar/_button_episode.html", conn: conn, item: item, episode: item.object)
      item.image -> render("toolbar/_button_image.html", conn: conn, item: item)
      true -> ""
    end
  end

  def slug(item) do
    item.headline
    |> String.downcase
    |> String.replace(~r/[^a-z0-9\s]/, "")
    |> String.replace(~r/\s+/, "-")
    |> Kernel.<>("-#{hashid(item)}")
  end

  def hashid(item) do
    Hashid.encode(item.id)
  end

  def teaser(item, max_words \\ 20) do
    item.story
    |> md_to_html
    |> prepare_html
    |> String.split
    |> truncate(word_count(item.story), max_words)
    |> Enum.join(" ")
  end

  def topic_list(item) do
    item.topics
    |> Enum.map(&("##{&1.slug}"))
    |> Enum.join(" ")
  end

  def topic_link_list(conn, item) do
    item.topics
    |> Enum.map(fn(topic) ->
      {:safe, el} = link("\##{topic.slug}", to: topic_path(conn, :show, topic.slug), title: "View #{topic.name}")
      el
      end)
    |> Enum.join(" ")
  end

  defp prepare_html(html) do
    html
    |> String.replace("\n", " ") # treat news lines as spaces
    |> String.replace(Regexp.tag("p"), "") # remove p tags
    |> String.replace(~r/(<\w+>)\s+(\S)/, "\\1\\2" ) # attach open tags to next word
    |> String.replace(~r/(\S)\s+(<\/\w+>)/, "\\1\\2" ) # attach close tags to prev word
    |> String.replace(Regexp.tag("blockquote"), "\\1i\\2") # treat as italics
  end

  defp truncate(html_list, total_words, max_words) when total_words <= max_words, do: html_list
  defp truncate(html_list, _total_words, max_words) do
    sliced = Enum.slice(html_list, 0..(max_words-1))
    tags = Regex.scan(Regexp.tag, Enum.join(sliced, " "), capture: ["tag"]) |> List.flatten

    sliced ++ case Integer.mod(length(tags), 2) do
      0 -> ["..."]
      1 -> ["</#{List.last(tags)}>", "..."]
    end
  end
end
