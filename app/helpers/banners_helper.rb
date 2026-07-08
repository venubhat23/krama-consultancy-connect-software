module BannersHelper
  # Display banners for a specific location
  def display_banners(location)
    # Disable sidebar banners completely
    return if location == 'sidebar'

    banners = Banner.active
                    .current
                    .by_location(location)
                    .ordered

    return if banners.empty?

    content_tag :div, class: "banners-container mb-4" do
      banners.map do |banner|
        render_banner(banner)
      end.join.html_safe
    end
  end

  # Render sidebar ad banners with special styling
  def render_sidebar_banners(banners)
    content_tag :div, class: "sidebar-ad-banners" do
      banners.map do |banner|
        render_sidebar_banner(banner)
      end.join.html_safe
    end
  end

  # Render a single sidebar banner
  def render_sidebar_banner(banner)
    content_tag :div, class: "sidebar-ad-item card border-0 shadow-sm mb-3", data: { banner_id: banner.id } do
      if banner.has_image?
        content_tag :div, class: "sidebar-ad-image-container position-relative" do
          image_content = image_tag(banner.banner_image_url, class: "sidebar-ad-image w-100", alt: banner.title)
          overlay_content = content_tag :div, class: "sidebar-ad-overlay position-absolute bottom-0 start-0 end-0 p-2" do
            content_tag :div, class: "d-flex justify-content-between align-items-center" do
              text_content = content_tag :div do
                title = content_tag :h6, banner.title, class: "sidebar-ad-title mb-0 text-white"
                desc = banner.description.present? ? content_tag(:small, truncate(banner.description, length: 60), class: "sidebar-ad-desc text-white-50") : "".html_safe
                title + desc
              end

              dismiss_btn = content_tag :button, type: "button", class: "btn-close btn-close-white btn-sm",
                                       data: { bs_dismiss: "alert", banner_id: banner.id },
                                       aria: { label: "Close" } do
              end

              text_content + dismiss_btn
            end
          end

          link_wrapper = if banner.redirect_link.present?
            link_to banner.redirect_link, target: "_blank", rel: "noopener", class: "sidebar-ad-link" do
              image_content + overlay_content
            end
          else
            image_content + overlay_content
          end

          link_wrapper
        end
      else
        content_tag :div, class: "sidebar-ad-text card-body p-3" do
          header_content = content_tag :div, class: "d-flex justify-content-between align-items-start mb-2" do
            title_content = content_tag :h6, banner.title, class: "sidebar-ad-title mb-1"
            dismiss_btn = content_tag :button, type: "button", class: "btn-close btn-sm",
                                     data: { bs_dismiss: "alert", banner_id: banner.id },
                                     aria: { label: "Close" } do
            end
            title_content + dismiss_btn
          end

          desc_content = if banner.description.present?
            content_tag :p, banner.description, class: "sidebar-ad-desc small text-muted mb-2"
          else
            "".html_safe
          end

          link_content = if banner.redirect_link.present?
            content_tag :div, class: "mt-2" do
              link_to "Learn More →", banner.redirect_link, class: "btn btn-primary btn-sm w-100", target: "_blank", rel: "noopener"
            end
          else
            "".html_safe
          end

          header_content + desc_content + link_content
        end
      end
    end
  end

  # Render a single banner
  def render_banner(banner)
    content_tag :div, class: "banner-item card border-0 shadow-sm mb-3", data: { banner_id: banner.id } do
      banner_content = content_tag :div, class: "card-body" do
        banner_body_content(banner)
      end

      if banner.has_image?
        content_tag(:div, class: "position-relative") do
          image_tag(banner.banner_image_url, class: "card-img-top", style: "height: 200px; object-fit: cover;") +
          content_tag(:div, banner_body_content(banner), class: "position-absolute bottom-0 start-0 end-0 bg-dark bg-opacity-75 text-white p-3")
        end
      else
        banner_content
      end
    end
  end

  # Generate banner body content
  def banner_body_content(banner)
    content = content_tag :div, class: "d-flex justify-content-between align-items-start" do
      banner_text = content_tag :div do
        title_content = content_tag :h5, banner.title, class: "card-title mb-2"
        description_content = if banner.description.present?
          content_tag :p, banner.description, class: "card-text mb-2"
        else
          "".html_safe
        end

        title_content + description_content
      end

      dismiss_button = content_tag :button, type: "button", class: "btn-close btn-close-white",
                                   data: { bs_dismiss: "alert", banner_id: banner.id },
                                   aria: { label: "Close" } do
      end

      banner_text + dismiss_button
    end

    # Add action link if redirect_link is present
    if banner.redirect_link.present?
      content += content_tag :div, class: "mt-3" do
        link_to "Learn More", banner.redirect_link,
                class: "btn btn-light btn-sm",
                target: "_blank",
                rel: "noopener"
      end
    end

    content
  end

  # Get banner count for a location
  def banner_count(location)
    Banner.active.current.by_location(location).count
  end

  # Check if there are active banners for a location
  def has_banners?(location)
    banner_count(location) > 0
  end

  # Banner location options for forms
  def banner_location_options
    [
      ['Dashboard', 'dashboard'],
      ['Login Page', 'login'],
      ['Home Page', 'home'],
      ['Sidebar Ad', 'sidebar']
    ]
  end

  # Banner status badge
  def banner_status_badge(banner)
    if banner.active?
      content_tag :span, "Active", class: "badge bg-success"
    elsif !banner.status?
      content_tag :span, "Inactive", class: "badge bg-secondary"
    elsif banner.expired?
      content_tag :span, "Expired", class: "badge bg-danger"
    elsif banner.upcoming?
      content_tag :span, "Upcoming", class: "badge bg-warning"
    else
      content_tag :span, "Unknown", class: "badge bg-light text-dark"
    end
  end

  # Banner period status
  def banner_period_status(banner)
    if banner.current?
      { text: "Current", class: "text-success", icon: "bi-circle-fill" }
    elsif banner.expired?
      { text: "Expired", class: "text-danger", icon: "bi-circle-fill" }
    elsif banner.upcoming?
      { text: "Upcoming", class: "text-warning", icon: "bi-circle-fill" }
    else
      { text: "Unknown", class: "text-muted", icon: "bi-circle" }
    end
  end
end