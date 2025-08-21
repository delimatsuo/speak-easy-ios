#!/usr/bin/env ruby
require 'xcodeproj'

# Path to your .xcodeproj file
project_path = '/Users/delimatsuo/Documents/Codingclaude/UniversalTranslatorApp/iOS/UniversalTranslator.xcodeproj'
project = Xcodeproj::Project.open(project_path)

puts "🔧 Fixing Chinese localization in Xcode project..."

# Step 1: Remove any remaining zh-Hans references
project.objects.each do |uuid, object|
  if object.respond_to?(:path) && object.path&.include?('zh-Hans')
    puts "🗑️ Removing stale reference: #{object.path}"
    object.remove_from_project
  elsif object.respond_to?(:name) && object.name&.include?('zh-Hans')
    puts "🗑️ Removing stale reference: #{object.name}"
    object.remove_from_project
  end
end

# Step 2: Create Chinese localization file
puts "📁 Creating Chinese localization file..."
chinese_dir = '/Users/delimatsuo/Documents/Codingclaude/UniversalTranslatorApp/iOS/Resources/Localization/zh-CN.lproj'
Dir.mkdir(chinese_dir) unless Dir.exist?(chinese_dir)

# Create Chinese localization content
chinese_content = <<~STRINGS
/* 
  Localizable.strings
  UniversalTranslator
  
  Chinese Simplified localization
*/

// App Name
"app_name" = "Universal AI Translator";
"app_subtitle" = "说话即时翻译";

// Main Screen
"tap_to_speak" = "点击说话";
"listening" = "正在聆听...";
"processing" = "正在处理...";
"translating" = "正在翻译...";
"playing" = "正在播放...";
"speak_in" = "说话语言";
"translate_to" = "翻译为";

// Language Names - ONLY GEMINI 2.5 FLASH TTS SUPPORTED
"language_en" = "英语";
"language_es" = "西班牙语";
"language_fr" = "法语";
"language_de" = "德语";
"language_it" = "意大利语";
"language_pt" = "葡萄牙语";
"language_zh" = "中文";
"language_ja" = "日语";
"language_ru" = "俄语";
"language_ko" = "韩语";
"language_ar" = "阿拉伯语";
"language_hi" = "印地语";

// Phase 1: Major Market Languages
"language_id" = "印尼语";
"language_vi" = "越南语";
"language_tr" = "土耳其语";
"language_th" = "泰语";
"language_pl" = "波兰语";

// Phase 2: Regional Powerhouses
"language_bn" = "孟加拉语";
"language_te" = "泰卢固语";
"language_mr" = "马拉地语";
"language_ta" = "泰米尔语";
"language_uk" = "乌克兰语";
"language_ro" = "罗马尼亚语";

// Credits
"credits_remaining" = "剩余 %d 秒";
"no_credits" = "没有剩余额度";
"purchase_credits" = "购买额度";
"low_balance_warning" = "余额不足：剩余 %d 秒";

// Errors
"error_title" = "错误";
"error_microphone_permission" = "需要麦克风权限。请在设置 > 隐私与安全性 > 麦克风中启用。";
"error_network" = "网络连接错误。请检查您的网络连接。";
"error_translation_failed" = "翻译服务不可用。请稍后重试。";
"error_no_audio" = "未录制到音频。请重试。";
"error_api_key" = "API配置错误。请联系客服。";

// Settings/Profile
"profile" = "个人资料";
"settings" = "设置";
"sign_out" = "退出登录";
"delete_account" = "删除账户";
"delete_account_confirm" = "您确定要删除账户吗？此操作无法撤销。";
"cancel" = "取消";
"delete" = "删除";
"done" = "完成";

// Purchase
"purchase_title" = "购买翻译额度";
"purchase_subtitle" = "选择额度套餐";
"purchase_300s" = "5分钟 - ¥6";
"purchase_1800s" = "30分钟 - ¥30";
"purchase_3600s" = "1小时 - ¥54";
"purchase_7200s" = "2小时 - ¥90";
"purchase_footer" = "额度按翻译时长计算（秒）。购买后不可退款。";
"restore_purchases" = "恢复购买";

// Legal
"terms_of_use" = "使用条款";
"privacy_policy" = "隐私政策";
"consent_title" = "欢迎使用Universal AI Translator";
"consent_message" = "我们保护您的隐私：不存储对话内容，仅保留最少的购买和会话元数据最多12个月。";
"agree_and_continue" = "同意并继续";

// Sign In
"sign_in_title" = "登录";
"sign_in_subtitle" = "匿名登录即可开始使用";
"sign_in_anonymous" = "以访客身份继续";
"signing_in" = "正在登录...";

// Common Actions
"ok" = "确定";
"retry" = "重试";
"close" = "关闭";
"loading" = "加载中...";
"copied" = "已复制到剪贴板";
STRINGS

File.write("#{chinese_dir}/Localizable.strings", chinese_content)
puts "✅ Created Chinese localization file: #{chinese_dir}/Localizable.strings"

# Step 3: Add Chinese back to the project with zh-CN (Google Cloud TTS standard)
puts "📱 Adding zh-CN localization to Xcode project..."

# Find or create Resources group
resources_group = project.main_group['Resources'] || project.main_group.new_group('Resources')
localization_group = resources_group['Localization'] || resources_group.new_group('Localization')

# Find or create the variant group for Localizable.strings
variant_group = project.main_group.recursive_children.find { |child| 
  child.is_a?(Xcodeproj::Project::Object::PBXVariantGroup) && child.name == 'Localizable.strings' 
}

if variant_group.nil?
  variant_group = localization_group.new_variant_group('Localizable.strings')
  project.targets.first.resources_build_phase.add_file_reference(variant_group)
end

# Add the Chinese localization file to the variant group
strings_file_path = "#{chinese_dir}/Localizable.strings"
file_ref = variant_group.new_reference(strings_file_path)
file_ref.name = 'zh-CN'

# Add zh-CN to known regions (using Google Cloud TTS standard)
current_regions = project.root_object.known_regions || []
unless current_regions.include?('zh-CN')
  project.root_object.known_regions = current_regions + ['zh-CN']
  puts "✅ Added 'zh-CN' to known regions"
end

# Save the project
project.save

puts "✅ Chinese localization restored with zh-CN (Google Cloud TTS standard)"
puts "📱 Xcode project updated successfully"
