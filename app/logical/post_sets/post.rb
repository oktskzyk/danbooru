module PostSets
  class Post < PostSets::Base
    attr_reader :tag_array, :page, :per_page, :raw, :random, :post_count, :format

    def initialize(tags, page = 1, per_page = nil, options = {})
      @tag_array = Tag.scan_query(tags)
      @page = page
      @per_page = (per_page || CurrentUser.per_page).to_i
      @per_page = 200 if @per_page > 200
      @raw = options[:raw].present?
      @random = options[:random].present?
      @format = options[:format] || "html"
    end

    def tag_string
      @tag_string ||= tag_array.uniq.join(" ")
    end

    def humanized_tag_string
      tag_array.slice(0, 25).join(" ").tr("_", " ")
    end

    def unordered_tag_array
      tag_array.reject{|tag| tag =~ /\Aorder:\S+/}
    end

    def has_wiki?
      is_single_tag? && ::WikiPage.titled(tag_string).exists?
    end

    def wiki_page
      if is_single_tag?
        ::WikiPage.titled(tag_string).first
      else
        nil
      end
    end

    def has_artist?
      is_single_tag? && artist.present? && artist.visible?
    end

    def artist
      @artist ||= ::Artist.named(tag_string).active.first
    end

    def pool_name
      tag_string.match(/^(?:ord)?pool:(\S+)$/i).try(:[], 1)
    end

    def has_pool?
      is_single_tag? && pool_name && pool
    end

    def pool
      ::Pool.find_by_name(pool_name)
    end

    def favgroup_name
      tag_string.match(/^favgroup:(\S+)$/i).try(:[], 1)
    end

    def has_favgroup?
      is_single_tag? && favgroup_name && favgroup
    end

    def favgroup
      ::FavoriteGroup.find_by_name(favgroup_name)
    end

    def has_deleted?
      tag_string !~ /status/ && ::Post.tag_match("#{tag_string} status:deleted").exists?
    end

    def has_explicit?
      posts.any? {|x| x.rating == "e"}
    end

    def use_sequential_paginator?
      unknown_post_count? && !CurrentUser.is_gold?
    end

    def get_post_count
      if %w(json atom xml).include?(format.downcase)
        # no need to get counts for formats that don't use a paginator
        return Danbooru.config.blank_tag_search_fast_count
      else
        ::Post.fast_count(tag_string)
      end
    end

    def get_random_posts
      if unknown_post_count?
        chance = 0.01
      elsif post_count == 0
        chance = 1
      else
        chance = per_page / post_count.to_f
      end

      temp = []
      temp += ::Post.tag_match(tag_string).where("random() < ?", chance).reorder("").limit(per_page)

      3.times do
        missing = per_page - temp.length
        if missing >= 1
          q = ::Post.tag_match(tag_string).where("random() < ?", chance*2).reorder("").limit(missing)
          unless temp.empty?
            q = q.where("id not in (?)", temp.map(&:id))
          end
          temp += q
        end
      end

      temp
    end

    def posts
      if tag_array.any? {|x| x =~ /^-?source:.*\*.*pixiv/} && !CurrentUser.user.is_builder?
        raise SearchError.new("Your search took too long to execute and was canceled")
      end

      @posts ||= begin
        @post_count = get_post_count()

        if random
          temp = get_random_posts()
        elsif raw
          temp = ::Post.raw_tag_match(tag_string).order("posts.id DESC").paginate(page, :count => post_count, :limit => per_page)
        else
          temp = ::Post.tag_match(tag_string).paginate(page, :count => post_count, :limit => per_page)
        end
        temp.each # hack to force rails to eager load
        temp
      end
    end

    def unknown_post_count?
      post_count == Danbooru.config.blank_tag_search_fast_count
    end

    def is_single_tag?
      tag_array.size == 1
    end

    def is_empty_tag?
      tag_array.size == 0
    end

    def is_pattern_search?
      is_single_tag? && tag_string =~ /\*/ && !tag_array.any? {|x| x =~ /^-?source:.+/}
    end

    def current_page
      [page.to_i, 1].max
    end

    def is_tag_subscription?
      tag_subscription.present?
    end

    def tag_subscription
      @tag_subscription ||= tag_array.select {|x| x =~ /^sub:/}.map {|x| x.sub(/^sub:/, "")}.first
    end

    def tag_subscription_tags
      @tag_subscription_tags ||= TagSubscription.find_tags(tag_subscription)
    end

    def presenter
      @presenter ||= ::PostSetPresenters::Post.new(self)
    end
  end
end
