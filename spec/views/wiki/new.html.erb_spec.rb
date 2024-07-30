#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++

require "spec_helper"

RSpec.describe "wiki/new" do
  let(:project) { build_stubbed(:project) }
  let(:wiki)    { build_stubbed(:wiki, project:) }
  let(:page)    { build_stubbed(:wiki_page, wiki:, title: "foo") }
  # TODO: remove
  let(:content) { page }
  let(:user)    { build_stubbed(:user) }

  before do
    assign(:project, project)
    assign(:wiki,    wiki)
    assign(:page,    page)
    assign(:content, content)
    allow(view)
      .to receive(:current_user)
      .and_return(user)
  end

  it "renders a form which POSTs to create_project_wiki_index_path" do
    project.identifier = "my_project"
    render
    assert_select "form",
                  action: create_project_wiki_index_path(project_id: project),
                  method: "post"
  end

  it "contains an input element for title" do
    page.title = "Boogie"

    render
    assert_select "input", name: "page[title]", value: "Boogie"
  end

  it "contains an input element for parent page" do
    page.parent_id = 123

    render
    assert_select "input", name: "page[parent_id]", value: "123", type: "hidden"
  end
end
