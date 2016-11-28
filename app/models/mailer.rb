#
# Copyright (C) 2011 - 2015 Instructure, Inc.
#
# This file is part of Canvas.
#
# Canvas is free software: you can redistribute it and/or modify it under
# the terms of the GNU Affero General Public License as published by the Free
# Software Foundation, version 3 of the License.
#
# Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
# details.
#
# You should have received a copy of the GNU Affero General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.
#

require 'mail'

class Mailer < ActionMailer::Base

  attr_reader :email

  class << self

    # for aliyun
    attr_accessor :use_aliyun, :aliyun_account_name, :aliyun_key, :aliyun_secret

    # 发送邮件
    def deliver(m)
      if use_aliyun
        deliver_to_aliyun(m)
      else
        create_message(m).deliver
      end
    end

    # 使用阿里云发送邮件
    def deliver_to_aliyun(m)
      mail = AliyunMail::SingleMailer.new(aliyun_account_name, aliyun_key, aliyun_secret)
      mail.add_dst_addrs(m.to) if m.to.is_a?(Array)
      mail.add_dst_addrs([m.to]) if m.to.is_a?(String)

      if m.body
        mail.set_text_body(m.body)
      else
        # 优先发送文字信息，如果有文字信息就不发送html信息
        # 因为注册确认邮件会被阿里云判定为垃圾邮件
        mail.set_html_body(m.html_body) if m.html_body
      end

      mail.set_src_alias(m.from_name || HostUrl.outgoing_email_default_name)
      mail.set_subject(m.subject)
      result = mail.send
      raise Net::SMTPServerBusy, 'deliver email by aliyun failed!' unless result
    end
  end

  # define in rails3-style
  def create_message(m)
    # notifications have context, bounce replies don't.
    headers('Auto-Submitted' => m.context ? 'auto-generated' : 'auto-replied')

    params = {
      from: from_mailbox(m),
      to: m.to,
      subject: m.subject
    }

    reply_to = reply_to_mailbox(m)
    params[:reply_to] = reply_to if reply_to

    mail(params) do |format|
      format.text{ render text: m.body }
      format.html{ render text: m.html_body } if m.html_body
    end
  end

  private
  def quoted_address(display_name, address)
    addr = Mail::Address.new(address)
    addr.display_name = display_name
    addr.format
  end

  def from_mailbox(message)
    quoted_address(message.from_name || HostUrl.outgoing_email_default_name, HostUrl.outgoing_email_address)
  end

  def reply_to_mailbox(message)
    address = IncomingMail::ReplyToAddress.new(message).address
    return address unless message.reply_to_name.present?
    return nil unless address.present?

    quoted_address(message.reply_to_name, address)
  end
end
