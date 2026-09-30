Rails.application.config.content_security_policy do |policy|
  policy.default_src :self
  policy.font_src :self
  policy.img_src :self, :data
  policy.style_src :self
  policy.script_src "https://scripts.withcabin.com"
  policy.connect_src :self, "https://ping.withcabin.com"
  policy.object_src :none
  policy.base_uri :self
  policy.form_action :self
  policy.frame_ancestors :none
end
