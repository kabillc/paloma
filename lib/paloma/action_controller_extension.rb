module Paloma


  module ActionControllerExtension

    def self.included base
      base.send :include, InstanceMethods

      base.module_eval do
        prepend_view_path "#{Paloma.root}/app/views/"

        before_filter :track_paloma_request
        after_filter :append_paloma_hook, :if => :html_is_rendered?
      end
    end





    module InstanceMethods

      #
      # Use on controllers to pass variables to Paloma controller.
      #
      def js params = {}
        return @__paloma_request = nil if !params
        @__paloma_request[:params] = params
      end


      #
      # Executed every time a controller action is executed.
      #
      # Keeps track of what Rails controller/action is executed.
      #
      def track_paloma_request
        resource = controller_path.split('/').map(&:titleize).join('/').gsub(' ', '')

        @__paloma_request = {:resource => resource, :action => self.action_name}
      end


      #
      # Before rendering html reponses,
      # this is exectued to append Paloma's html hook to the response.
      #
      # The html hook contains the javascript code that
      # will execute the tracked Paloma requests.
      #
      def append_paloma_hook
        return true if @__paloma_request.nil?

        hook = view_context.render(
                  :partial => 'paloma/hook',
                  :locals => {:request => @__paloma_request})

        before_body_end_index = response_body[0].rindex('</body>')

        # Append the hook after the body tag if it is present.
        if before_body_end_index.present?
          before_body = response_body[0][0, before_body_end_index].html_safe
          after_body = response_body[0][before_body_end_index..-1].html_safe

          response.body = before_body + hook + after_body
        else
          # If body tag is not present, append hook in the response body
          response.body += hook
        end

        @__paloma_request = nil
      end
    end


    def html_is_rendered?
      not_redirect = self.status != 302
      [nil, 'text/html'].include?(response.content_type) && not_redirect
    end


    #
    # Make sure not to execute paloma on the following response type
    #
    def render options = nil, extra_options = {}, &block
      [:json, :js, :xml, :file].each do |format|
        js false if options.has_key?(format)
      end if options.is_a?(Hash)

      super
    end
  end


  ::ActionController::Base.send :include, ActionControllerExtension
end
