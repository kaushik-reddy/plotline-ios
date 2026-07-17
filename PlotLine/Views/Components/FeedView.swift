import SwiftUI

/// The social feed — a native port of the web `Feed.tsx`: an avatar-node timeline of posts
/// with a green rating chip, likes, inline replies, a Following↔Global toggle and #tag filter.
struct FeedView: View {
    @Environment(FeedStore.self) private var feed

    var body: some View {
        @Bindable var feed = feed
        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                SectionHeader(title: "Feed", kicker: "From people you follow")
                Spacer()
                Picker("", selection: $feed.mode) {
                    ForEach(FeedMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }

            if !feed.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(feed.tags, id: \.self) { tag in
                            let active = feed.tagFilter == tag
                            Button {
                                feed.tagFilter = active ? nil : tag
                            } label: {
                                Text(tag)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(active ? .black : Theme.green)
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(active ? Theme.green : Theme.green.opacity(0.12), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            ForEach(feed.visiblePosts) { post in
                PostRow(post: post)
            }
        }
        .padding(.horizontal, 16)
    }
}

private struct PostRow: View {
    let post: FeedPost
    @Environment(FeedStore.self) private var feed
    @State private var posterPath: String?
    @State private var showReply = false
    @State private var replyText = ""

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Timeline node + connector.
            VStack(spacing: 4) {
                AvatarView(seed: post.persona.seed, size: 36)
                Rectangle().fill(Theme.line).frame(width: 1).frame(maxHeight: .infinity)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text(post.persona.name).font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.text)
                    Text("@\(post.persona.handle)").font(.system(size: 12)).foregroundStyle(Theme.muted)
                    Text("· \(post.when)").font(.system(size: 12)).foregroundStyle(Theme.faint)
                    Spacer()
                }

                // Title reference chip.
                NavigationLink(value: TitleRef(media: post.media, id: post.tmdbId)) {
                    HStack(spacing: 10) {
                        RemoteImage(path: posterPath, size: "w92")
                            .frame(width: 34, height: 34 / Theme.posterAspect)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(post.titleName).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Theme.text).lineLimit(1)
                            Text(post.scopeLabel).font(.system(size: 10.5)).foregroundStyle(Theme.muted).lineLimit(1)
                        }
                        Spacer()
                        HStack(spacing: 3) {
                            Image(systemName: "star.fill").font(.system(size: 10)).foregroundStyle(Theme.green)
                            Text("\(Int(post.rating))/10").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.green)
                        }
                    }
                    .padding(8)
                    .background(Theme.panel, in: RoundedRectangle(cornerRadius: Theme.radius))
                    .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.line, lineWidth: 1))
                }
                .buttonStyle(.plain)

                Text(post.text)
                    .font(.system(size: 13.5))
                    .foregroundStyle(Theme.text.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)

                // Actions.
                HStack(spacing: 18) {
                    Button {
                        feed.toggleLike(post.id)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: feed.isLiked(post.id) ? "heart.fill" : "heart")
                                .foregroundStyle(feed.isLiked(post.id) ? Theme.red : Theme.muted)
                            Text("\(feed.likeCount(post.id))").foregroundStyle(Theme.muted)
                        }
                        .font(.system(size: 12.5, weight: .semibold))
                    }
                    .buttonStyle(.plain)

                    Button { showReply.toggle() } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "bubble.right")
                            Text("Reply · \(feed.replies(for: post.id).count)")
                        }
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Theme.muted)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }

                // Replies.
                ForEach(feed.replies(for: post.id)) { reply in
                    HStack(alignment: .top, spacing: 8) {
                        AvatarView(seed: reply.persona.seed, size: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 5) {
                                Text(reply.persona.name).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.text)
                                Text("· \(reply.when)").font(.system(size: 11)).foregroundStyle(Theme.faint)
                            }
                            Text(reply.text).font(.system(size: 12.5)).foregroundStyle(Theme.text.opacity(0.85))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.leading, 4)
                }

                if showReply {
                    HStack(spacing: 8) {
                        TextField("Write a reply…", text: $replyText)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.text)
                            .padding(9)
                            .background(Theme.panelRaised, in: RoundedRectangle(cornerRadius: Theme.radius))
                        Button("Post") {
                            feed.addReply(to: post.id, text: replyText)
                            replyText = ""
                            showReply = false
                        }
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.orange)
                        .disabled(replyText.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .padding(.bottom, 6)
        }
        .task {
            if posterPath == nil {
                let d = await TMDBService.shared.get("/\(post.media.rawValue)/\(post.tmdbId)", as: TitleDetail.self)
                posterPath = d?.posterPath
            }
        }
    }
}
