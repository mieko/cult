# Future Plans

Here's some stuff I'd like to add to Cult:

  * `cult node disable /NODE+/` and `cult node enable /NODE+/` in a clean way.
    This means tasks won't see disabled nodes, so a node can be taken out of
    the set without destroying it.  `fetch_item[s]` probably needs to see the
    whole set (otherwise, how could you re-enable a disabled item?), but
    things like `nodes.each` need to skip them.  This should work:

    ```bash
    cult node disable /pgpool/
    cult node sync
    # Now all nodes connect directly to master
    cult node enable /pgpool/
    cult node sync
    # Now we're back to be first setup
    ```

  * A node needs a way to finish a task by saying "It's all good, but I'm gonna
    have to reboot, so do your SSH loop again".  The use case is a fresh node
    created from an image that has security updates available immediately.

  * Partition sets.  Lets say you have ten front-end servers ->
    two load balancers like pgpool -> three backend servers.  There needs to be
    a way for a front-end task to ask which load balancer to use that'd
    consistently put equal weight on each one.  If a load balancer is added or
    removed, it'd answer the question differently.  I'm thinking something
    like:

    ```ruby
    node.fair(role, :zone)
    ```

    Would return a node with that role, in that zone, and return a balanced
    list depending on 'node'.  For bonus points we could have weights on a
    per-node basis that `fair` would take into account.

  * Fully document `NamedArray` and its usage in both code and the command
    line. It's one of my favorite things about Cult, but I add features and
    syntax haphazardly that are awesome, but not fully explained.

  * Leader promotion/avoidance.  I should be able to do something like:
    `cult node promote -r some-role some-node`, and that'll make some-node the
    zone_leader? of some-role.  I should be able to `cult node demote` the
    node out of leader position, if it was previously promoted, OR if it were
    naturally selected.

  * Generalized events: Now `sync` is sort of baked-in.  It should just be a
    specific case of a generalized event-running system.

  * More environment separation: There should be warnings/confirmations in
    production, and be totally hard to fat-finger fuck up production.  I type
    `cult node rm //` dozens of times a day.  That doesn't need to work in
    production.  This might go as far as "cult env <something>" checking out
    a branch.  I don't have a problem tying Cult to git as an integral part of
    its operations.  We can always allow outside contributions for SCM adapters
    later.

  * General code clean-up.  Luckily, there aren't any huge architectural
    problems, but older code written while the vision was still up in the air
    isn't exactly stuff I'd put in my portfolio.  Particularly, we need a way
    to save and load nodes and roles without it being hard-coded into the CLI
    commands.  This would make stuff more usable from the console, too.

  * Some way to set project-global settings.  For example, in our instance,
    you can search the project for our OpenSSL cipher string and find it
    duplicated in 8-10 places.  We should be able to set that somewhere
    besides `base/role.json` and have a fast, convenient way to reference it
    from tasks or the console.

  * Adding roles:  With properly-written tasks, we should be able to add a role
    to an existing node.  We shouldn't even attempt to remove one.
